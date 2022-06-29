const std = @import("std");

const iter = @import("./iter.zig");

const SliceIter = @import("./to_iter.zig").SliceIter;
const ArrayIter = @import("./to_iter.zig").ArrayIter;
const ArrayListIter = @import("./to_iter.zig").ArrayListIter;
const SinglyLinkedListIter = @import("./to_iter.zig").SinglyLinkedListIter;

const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

pub fn have_type(comptime T: type, name: []const u8) ?type {
    if (!comptime @hasDecl(T, name)) {
        return null;
    }
    const field = @field(T, name);
    if (@typeInfo(@TypeOf(field)) == .Type) {
        return field;
    }
    return null;
}

pub fn have_field(comptime T: type, name: []const u8) ?type {
    const fields = switch (@typeInfo(T)) {
        .Struct => |s| s.fields,
        .Union => |u| u.fields,
        .Enum => |e| e.fields,
        else => false,
    };

    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            return field.field_type;
        }
    }

    return null;
}

pub fn have_fun(comptime T: type, name: []const u8) ?type {
    const decls = switch (@typeInfo(T)) {
        .Struct => |s| s.decls,
        .Union => |u| u.decls,
        .Enum => |e| e.decls,
        else => false,
    };

    inline for (decls) |decl| {
        if (std.mem.eql(u8, decl.name, name)) {
            switch (decl.data) {
                .Fn => |fndecl| return fndecl.fn_type,
                else => break,
            }
        }
    }

    return null;
}

pub fn isIterator(comptime T: type) bool {
    if (have_type(T, "Self")) |Self| {
        if (have_type(T, "Item")) |Item| {
            if (have_fun(T, "next")) |next_ty| {
                return next_ty == fn (*Self) ?Item;
            }
        }
    }
    return false;
}

comptime {
    assert(isIterator(ArrayIter(u32, 3)));
    assert(isIterator(SliceIter(u32)));
    assert(isIterator(ArrayListIter(u32)));
    assert(isIterator(SinglyLinkedListIter(u32)));
}

/// Fix :: ((type -> type) -> type -> type) -> type -> type
fn Fix(comptime F: fn (fn (type) type) fn (type) type) fn (type) type {
    const C = struct {
        pub fn call(comptime T: type) type {
            return Fix(F)(T);
        }
    };
    return F(C.call);
}

fn MakeIter(comptime F: fn (type) type, comptime Item: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Item;
        pub usingnamespace F(@This());

        slice: []const Item,
        index: u32,

        pub fn new(slice: []const Item) Self {
            return Self{ .slice = slice, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.index < self.slice.len) {
                const i = self.index;
                self.index += 1;
                return self.slice[i];
            } else {
                return null;
            }
        }
    };
}

fn DeriveMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));
    if (have_fun(Iter, "map")) |_| {
        return Iter;
    } else {
        // for avoiding dependency loop,
        // delay evaluation such like `(() -> e)()`
        var M = struct {
            pub const N = struct {
                pub fn map(self: Iter, f: anytype) iter.IterMap(Iter, @TypeOf(f)) {
                    return iter.IterMap(Iter, @TypeOf(f)).new(f, self);
                }
            };
        };
        return M.N;
    }
}

/// https://lyrical-logical.hatenadiary.org/entry/20111107/1320671610
fn impl_map(comptime F: fn (type) type) fn (type) type {
    const C = struct {
        pub fn call(comptime T: type) type {
            assert(isIterator(T));
            // conflict to existing function
            //@compileLog("call: ");
            //inline for (@typeInfo(T).Struct.decls) |decl| {
            //    @compileLog("\tdecl: ", decl.name);
            //}
            if (have_fun(T, "map")) |_| {
                //@compileLog("have_map");
                return T;
            } else {
                //@compileLog("not have_map");
                // cannot override 'Self'
                var M = struct {
                    pub const N = struct {
                        pub usingnamespace T;
                        //pub const Self = @This();

                        pub fn map(self: *T.Self, f: anytype) iter.IterMap(T.Self, @TypeOf(f)) {
                            return iter.IterMap(T.Self, @TypeOf(f)).new(f, self);
                        }
                    };
                };
                assert(have_fun(M.N, "map") != null);
                //M.Self = @TypeOf(M);
                return F(M.N);
            }
        }
    };
    return C.call;

    // cannot reify declarations with @Type
    // const TypeInfo = std.builtin.TypeInfo;
    // var info: TypeInfo = @typeInfo(T);
    // var decls: [info.Struct.decls.len + 1]TypeInfo.Declaration = undefined;
    // var i = 0;
    // while (i < info.Struct.decls.len) : (i += 1) {
    //     decls[i] = info.Struct.decls[i];
    // }
    // decls[i] = @typeInfo(struct {
    //     pub fn map(self: *@This(), f: anytype) iter.IterMap(@This(), @TypeOf(f)) {
    //         return iter.IterMap(@This(), @TypeOf(f)).new(self, f);
    //     }
    // }).Struct.decls[0];
    // @compileLog("info.Struct.decls:", info.Struct.decls);
    // var ty = @Type(info);
    // info.Struct.decls[0].data = .{ .Type = ty };
    // return @Type(ty);
}

test "impl_map" {
    const arr = [_]u32{ 1, 2, 3 };
    var slice = SliceIter(u32).new(arr[0..]);
    try testing.expect(slice.next().? == 1);
    try testing.expect(slice.next().? == 2);
    try testing.expect(slice.next().? == 3);
    try testing.expect(slice.next() == null);

    const Double = struct {
        pub fn apply(x: u32) u32 {
            return x * 2;
        }
    };
    _ = Double;

    var map = MakeIter(DeriveMap, u32).new(arr[0..]).map(Double.apply);
    try testing.expect(map.next().? == 2);
    try testing.expect(map.next().? == 4);
    try testing.expect(map.next().? == 6);
    try testing.expect(map.next() == null);

    const SliceIterMap = Fix(impl_map)(SliceIter(u32));
    assert(isIterator(SliceIterMap));

    // var map = SliceIterMap.new(arr[0..]).map(Double.apply);
    // try testing.expect(map.next().? == 2);
    // try testing.expect(map.next().? == 4);
    // try testing.expect(map.next().? == 6);
    // try testing.expect(map.next() == null);
}
