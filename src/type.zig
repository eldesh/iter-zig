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

fn impl_map(comptime T: type) type {
    assert(isIterator(T));
    // conflict to existing function
    assert(have_fun(T, "map") == null);
    return void;

    // cannot override 'Self'
    // var M = struct {
    //     pub usingnamespace T;
    //     pub const Self = @This();

    //     pub fn map(self: *T.Self, f: anytype) iter.IterMap(T.Self, @TypeOf(f)) {
    //         return iter.IterMap(T.Self, @TypeOf(f)).new(f, self);
    //     }
    // };
    // M.Self = @TypeOf(M);
    // return M;

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

// test "impl_map" {
//     const SliceIterMap = impl_map(SliceIter(u32));
//     assert(isIterator(SliceIterMap));
//
//     const arr = [_]u32{ 1, 2, 3 };
//     var slice = SliceIter(u32).new(arr[0..]);
//     try testing.expect(slice.next().? == 1);
//     try testing.expect(slice.next().? == 2);
//     try testing.expect(slice.next().? == 3);
//     try testing.expect(slice.next() == null);
//
//     const Double = struct {
//         pub fn apply(x: u32) u32 {
//             return x * 2;
//         }
//     };
//
//     var map = SliceIterMap.new(arr[0..]).map(Double.apply);
//     try testing.expect(map.next().? == 2);
//     try testing.expect(map.next().? == 4);
//     try testing.expect(map.next().? == 6);
//     try testing.expect(map.next() == null);
// }
