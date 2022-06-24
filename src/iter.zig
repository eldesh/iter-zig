const std = @import("std");
const meta = meta;
const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

const SliceIter = @import("./to_iter.zig").SliceIter;
const ArrayIter = @import("./to_iter.zig").ArrayIter;
const ArrayListIter = @import("./to_iter.zig").ArrayListIter;
const SinglyLinkedListIter = @import("./to_iter.zig").SinglyLinkedListIter;

fn is_func_type(comptime F: type) bool {
    const TypeInfo: type = std.builtin.TypeInfo;
    const FInfo: TypeInfo = @typeInfo(F);
    return switch (FInfo) {
        .Fn => |_| true,
        else => false,
    };
}

fn is_unary_func_type(comptime F: type) bool {
    const TypeInfo: type = std.builtin.TypeInfo;
    const FInfo: TypeInfo = @typeInfo(F);
    return switch (FInfo) {
        .Fn => |f| f.args.len == 1,
        else => false,
    };
}

fn domain(comptime F: type) type {
    comptime {
        assert(is_unary_func_type(F));
    }
    const FInfo: std.builtin.TypeInfo = @typeInfo(F);
    return FInfo.Fn.args[0].arg_type.?;
}

fn codomain(comptime F: type) type {
    comptime {
        assert(is_func_type(F));
    }
    const FInfo: std.builtin.TypeInfo = @typeInfo(F);
    if (FInfo.Fn.return_type) |ty| {
        return ty;
    } else {
        return void;
    }
}

comptime {
    assert(domain(fn (u32) u16) == u32);
    assert(codomain(fn (u32) u16) == u16);
    assert(domain(fn (u32) []const u8) == u32);
    assert(codomain(fn (u32) []const u8) == []const u8);
}

pub fn IterMap(comptime Iter: type, comptime F: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = codomain(F);

        f: F,
        iter: Iter,

        pub fn new(f: F, iter: Iter) Self {
            return .{ .f = f, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                return self.f(item);
            } else {
                return null;
            }
        }
    };
}

comptime {
    assert(IterMap(SliceIter(u32), fn (u32) []u8).Self == IterMap(SliceIter(u32), fn (u32) []u8));
    assert(IterMap(SliceIter(u32), fn (u32) []u8).Item == []u8);
}

test "IterMap" {
    const Square = struct {
        pub fn f(v: u32) u64 {
            return v * v;
        }
    };
    const arr = [_]u32{ 1, 2, 3 };
    var arr_iter = ArrayIter(u32, arr.len).new(arr);
    var iter = IterMap(ArrayIter(u32, arr.len), fn (u32) u64).new(Square.f, arr_iter);
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 9);
    try testing.expect(iter.next() == null);
}

pub fn IterFilter(comptime Iter: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;

        pred: fn (Self.Item) bool,
        iter: Iter,

        pub fn new(pred: fn (Self.Item) bool, iter: Iter) Self {
            return .{ .pred = pred, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (self.pred(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}

test "IterFilter" {
    const IsEven = struct {
        pub fn f(value: u32) bool {
            return value % 2 == 0;
        }
    };

    const arr = [_]u32{ 1, 2, 3, 4, 5 } ** 3;
    var arr_iter = ArrayIter(u32, arr.len).new(arr);
    var iter = IterFilter(ArrayIter(u32, arr.len)).new(IsEven.f, arr_iter);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next() == null);
}

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
