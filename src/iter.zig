const std = @import("std");
const to_iter = @import("./to_iter.zig");
const derive = @import("./derive.zig");
const meta = @import("./type.zig");

const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

const SliceIter = to_iter.SliceIter;
const ArrayIter = to_iter.ArrayIter;

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

pub fn MakeIterMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = codomain(F);
        pub usingnamespace D(@This());

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

pub fn IterMap(comptime Iter: type, comptime F: type) type {
    return MakeIterMap(derive.Derive, Iter, F);
}

comptime {
    assert(IterMap(SliceIter(u32), fn (u32) []u8).Self == IterMap(SliceIter(u32), fn (u32) []u8));
    assert(IterMap(SliceIter(u32), fn (u32) []u8).Item == []u8);
    assert(meta.isIterator(IterMap(SliceIter(u32), fn (u32) []u8)));
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

pub fn MakeIterFilter(comptime D: fn (type) type, comptime Iter: type, comptime Pred: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        pred: Pred,
        iter: Iter,

        pub fn new(pred: Pred, iter: Iter) Self {
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

pub fn IterFilter(comptime Iter: type, comptime Pred: type) type {
    return MakeIterFilter(derive.Derive, Iter, Pred);
}

comptime {
    assert(IterFilter(SliceIter(u32), fn (u32) bool).Self == IterFilter(SliceIter(u32), fn (u32) bool));
    assert(IterFilter(SliceIter(u32), fn (u32) bool).Item == u32);
    assert(meta.isIterator(IterFilter(SliceIter(u32), fn (u32) bool)));
}

test "IterFilter" {
    const IsEven = struct {
        pub fn f(value: u32) bool {
            return value % 2 == 0;
        }
    };

    const arr = [_]u32{ 1, 2, 3, 4, 5 } ** 3;
    var arr_iter = ArrayIter(u32, arr.len).new(arr);
    var iter = IterFilter(ArrayIter(u32, arr.len), fn (u32) bool).new(IsEven.f, arr_iter);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next() == null);
}

pub fn MakeFlatMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(codomain(F));
        pub usingnamespace D(@This());

        f: F,
        iter: Iter,

        pub fn new(f: F, iter: Iter) Self {
            return .{ .f = f, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (self.f(item)) |v| {
                    return v;
                } else {
                    continue;
                }
            } else {
                return null;
            }
        }
    };
}

pub fn FlatMap(comptime Iter: type, comptime F: type) type {
    return MakeFlatMap(derive.Derive, Iter, F);
}

comptime {
    assert(FlatMap(SliceIter(u32), fn (u32) ?u8).Self == FlatMap(SliceIter(u32), fn (u32) ?u8));
    assert(FlatMap(SliceIter(u32), fn (u32) ?u8).Item == u8);
    assert(meta.isIterator(FlatMap(SliceIter(u32), fn (u32) ?u8)));
}
