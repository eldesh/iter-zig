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
    assert(IterMap(SliceIter(u32), fn (*const u32) []u8).Self == IterMap(SliceIter(u32), fn (*const u32) []u8));
    assert(IterMap(SliceIter(u32), fn (*const u32) []u8).Item == []u8);
    assert(meta.isIterator(IterMap(SliceIter(u32), fn (*const u32) []u8)));
}

test "IterMap" {
    const Square = struct {
        pub fn f(v: *const u32) u64 {
            return v.* * v.*;
        }
    };
    var arr = [_]u32{ 1, 2, 3 };
    var arr_iter = ArrayIter(u32, arr.len).new(&arr);
    var iter = IterMap(ArrayIter(u32, arr.len), fn (*const u32) u64).new(Square.f, arr_iter);
    try testing.expectEqual(@as(?u64, 1), iter.next());
    try testing.expectEqual(@as(?u64, 4), iter.next());
    try testing.expectEqual(@as(?u64, 9), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
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
    assert(IterFilter(SliceIter(u32), fn (*u32) bool).Self == IterFilter(SliceIter(u32), fn (*u32) bool));
    assert(IterFilter(SliceIter(u32), fn (*u32) bool).Item == *u32);
    assert(meta.isIterator(IterFilter(SliceIter(u32), fn (*u32) bool)));
}

test "IterFilter" {
    const IsEven = struct {
        pub fn f(value: *const u32) bool {
            return value.* % 2 == 0;
        }
    };
    var arr = [_]u32{ 1, 2, 3, 4, 5 } ** 3;
    var arr_iter = ArrayIter(u32, arr.len).new(&arr);
    var iter = IterFilter(ArrayIter(u32, arr.len), fn (*const u32) bool).new(IsEven.f, arr_iter);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());
}

pub fn MakeFilterMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(is_unary_func_type(F));
    comptime assert(std.meta.trait.is(.Optional)(codomain(F)));
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

pub fn FilterMap(comptime Iter: type, comptime F: type) type {
    return MakeFilterMap(derive.Derive, Iter, F);
}

comptime {
    assert(FilterMap(SliceIter(u32), fn (*const u32) ?u8).Self == FilterMap(SliceIter(u32), fn (*const u32) ?u8));
    assert(FilterMap(SliceIter(u32), fn (*const u32) ?u8).Item == u8);
    assert(meta.isIterator(FilterMap(SliceIter(u32), fn (*const u32) ?u8)));
}

test "FilterMap" {
    const ParseInt = struct {
        pub fn f(value: *const []const u8) ?u32 {
            return std.fmt.parseInt(u32, value.*, 10) catch null;
        }
    };
    var arr = [_][]const u8{ "abc", "123", "345", "-123.", "1abc" };
    var arr_iter = ArrayIter([]const u8, arr.len).new(&arr);
    var iter = FilterMap(ArrayIter([]const u8, arr.len), fn (*const []const u8) ?u32).new(ParseInt.f, arr_iter);
    try testing.expectEqual(@as(u32, 123), iter.next().?);
    try testing.expectEqual(@as(u32, 345), iter.next().?);
    try testing.expectEqual(@as(?u32, null), iter.next());
}

pub fn MakeChain(comptime D: fn (type) type, comptime Iter1: type, comptime Iter2: type) type {
    comptime assert(meta.isIterator(Iter1));
    comptime assert(meta.isIterator(Iter2));
    comptime assert(Iter1.Item == Iter2.Item);
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter1.Item;
        pub usingnamespace D(@This());

        iter1: Iter1,
        iter2: Iter2,
        iter1end: bool,

        pub fn new(iter1: Iter1, iter2: Iter2) Self {
            return .{ .iter1 = iter1, .iter2 = iter2, .iter1end = false };
        }

        pub fn next(self: *Self) ?Item {
            if (!self.iter1end) {
                if (self.iter1.next()) |v| {
                    return v;
                } else {
                    self.iter1end = true;
                    return self.iter2.next();
                }
            } else {
                return self.iter2.next();
            }
        }
    };
}

pub fn Chain(comptime Iter1: type, comptime Iter2: type) type {
    return MakeChain(derive.Derive, Iter1, Iter2);
}

comptime {
    assert(Chain(SliceIter(u32), ArrayIter(u32, 5)).Self == Chain(SliceIter(u32), ArrayIter(u32, 5)));
    assert(Chain(SliceIter(u32), ArrayIter(u32, 5)).Item == *u32);
    assert(meta.isIterator(Chain(SliceIter(u32), ArrayIter(u32, 5))));
}

test "Chain" {
    var arr1 = [_]u32{ 1, 2, 3 };
    var arr2 = [_]u32{ 4, 5, 6 };
    var iter1 = ArrayIter(u32, arr1.len).new(&arr1);
    var iter2 = SliceIter(u32).new(arr2[0..]);
    var iter = Chain(@TypeOf(iter1), @TypeOf(iter2)).new(iter1, iter2);
    try testing.expectEqual(@as(u32, 1), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 3), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 5), iter.next().?.*);
    try testing.expectEqual(@as(u32, 6), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());
}
