const std = @import("std");
const to_iter = @import("./to_iter.zig");
const derive = @import("./derive.zig");
const meta = @import("./type.zig");
const tuple = @import("./tuple.zig");
const range = @import("./range.zig");

const trait = std.meta.trait;
const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;
const assertEqualTuple = meta.assertEqualTuple;
const debug = std.debug.print;

const SliceIter = to_iter.SliceIter;
const ArrayIter = to_iter.ArrayIter;
const Tuple1 = tuple.Tuple1;
const Tuple2 = tuple.Tuple2;

fn is_func_type(comptime F: type) bool {
    const TypeInfo: type = std.builtin.TypeInfo;
    const FInfo: TypeInfo = @typeInfo(F);
    return switch (FInfo) {
        .Fn => |_| true,
        else => false,
    };
}

fn func_arity(comptime F: type) usize {
    comptime assert(is_func_type(F));
    return @typeInfo(F).Fn.args.len;
}

fn is_unary_func_type(comptime F: type) bool {
    return trait.is(.Fn)(F) and @typeInfo(F).Fn.args.len == 1;
}

fn is_binary_func_type(comptime F: type) bool {
    return trait.is(.Fn)(F) and @typeInfo(F).Fn.args.len == 2;
}

pub fn domain(comptime F: type) type {
    comptime {
        return std.meta.ArgsTuple(F);
    }
}

pub fn codomain(comptime F: type) type {
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
    assertEqualTuple(domain(fn (u32) u16), Tuple1(u32).StdTuple);
    assert(codomain(fn (u32) u16) == u16);
    assertEqualTuple(domain(fn (u32) []const u8), Tuple1(u32).StdTuple);
    assert(codomain(fn (u32) []const u8) == []const u8);
}

pub fn MakeZip(comptime D: fn (type) type, comptime Iter: type, comptime Other: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.isIterator(Other));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = tuple.Tuple2(Iter.Item, Other.Item);
        pub usingnamespace D(@This());

        iter: Iter,
        other: Other,

        pub fn new(iter: Iter, other: Other) Self {
            return .{ .iter = iter, .other = other };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |it| {
                if (self.other.next()) |jt| {
                    return tuple.tuple2(it, jt);
                }
                return null;
            }
            return null;
        }
    };
}

pub fn Zip(comptime Iter: type, comptime Other: type) type {
    return MakeZip(derive.Derive, Iter, Other);
}

comptime {
    const I = SliceIter;
    assert(Zip(I(u32), I(u32)).Self == Zip(I(u32), I(u32)));
    assert(Zip(I(u32), I(u32)).Item == tuple.Tuple2(*u32, *u32));
}

test "Zip" {
    const str = []const u8;
    const I = SliceIter;
    const R = range.RangeIter;
    const Iter = Zip(I(str), R(u32));
    var arr = [_]str{ "foo", "bar", "buzz" };
    var zip = Iter.new(I(str).new(arr[0..]), range.range(@as(u32, 2), 10, 1));

    // specialized ctor to Iter.Item
    const tup = tuple.Tuple2(*str, u32).new;
    try testing.expectEqual(tup(&arr[0], 2), zip.next().?);
    try testing.expectEqual(tup(&arr[1], 3), zip.next().?);
    try testing.expectEqual(tup(&arr[2], 4), zip.next().?);
    try testing.expectEqual(@as(?Iter.Item, null), zip.next());
}

pub fn MakeFlatMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type, comptime U: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.isIterator(U));
    comptime assert(F == fn (Iter.Item) U);

    return struct {
        pub const Self: type = @This();
        pub const Item: type = U.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        f: fn (Iter.Item) U,
        curr: ?U,

        pub fn new(iter: Iter, f: fn (Iter.Item) U) Self {
            return .{ .iter = iter, .f = f, .curr = null };
        }

        pub fn next(self: *Self) ?Item {
            if (self.curr == null) {
                self.curr = if (self.iter.next()) |item| self.f(item) else null;
            }
            while (self.curr) |_| : (self.curr = if (self.iter.next()) |item| self.f(item) else null) {
                if (self.curr.?.next()) |curr| {
                    return curr;
                }
            }
            return null;
        }
    };
}

pub fn FlatMap(comptime Iter: type, comptime F: type, comptime U: type) type {
    return MakeFlatMap(derive.Derive, Iter, F, U);
}

comptime {
    const I = SliceIter;
    assert(FlatMap(I(I(u32)), fn (*I(u32)) I(u32), I(u32)).Self ==
        FlatMap(I(I(u32)), fn (*I(u32)) I(u32), I(u32)));
    assert(FlatMap(I(I(u32)), fn (*I(u32)) I(u32), I(u32)).Item == *u32);
}

test "FlatMap" {
    const I = SliceIter;
    const R = range.RangeIter;
    const Iter = FlatMap(I(u32), fn (*u32) R(u32), R(u32));
    var arr = [_]u32{ 2, 3, 4 };
    var iter = Iter.new(I(u32).new(arr[0..]), struct {
        fn call(i: *const u32) R(u32) {
            return range.range(@as(u32, 0), i.*, 1);
        }
    }.call);

    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

pub fn PartialCmp(comptime Item: type) type {
    comptime assert(meta.isPartialOrd(Item));
    return struct {
        pub fn partial_cmp(iter: anytype, other: anytype) ?math.Order {
            const Iter = @TypeOf(iter);
            const Other = @TypeOf(other);
            comptime assert(Iter.Item == Item);
            comptime assert(Other.Item == Item);
            var it = iter;
            var ot = other;

            while (it.next()) |lval| {
                if (ot.next()) |rval| {
                    if (meta.PartialOrd.partial_cmp(lval, rval)) |ord| {
                        switch (ord) {
                            .eq => continue,
                            .lt, .gt => return ord,
                        }
                    } else return null;
                } else {
                    return .gt;
                }
            }
            return if (ot.next()) |_| .lt else .eq;
        }
    };
}

pub fn Cmp(comptime Item: type) type {
    comptime assert(meta.isOrd(Item));
    return struct {
        pub fn cmp(iter: anytype, other: anytype) math.Order {
            const Iter = @TypeOf(iter);
            const Other = @TypeOf(other);
            comptime assert(Iter.Item == Item);
            comptime assert(Other.Item == Item);
            var it = iter;
            var ot = other;

            while (it.next()) |lval| {
                if (ot.next()) |rval| {
                    const ord = meta.Ord.cmp(lval, rval);
                    switch (ord) {
                        .eq => continue,
                        .lt, .gt => return ord,
                    }
                } else {
                    return .gt;
                }
            }
            return if (ot.next()) |_| .lt else .eq;
        }
    };
}

/// The result type of `Product` type for primitive types.
///
/// # Details
/// Returns the type of result of multiplying elements of an iterators.
/// This functions defines for primitive types like:
///
/// - `ProductType(i64) == i64`
///   Return type itself.
/// - `ProductType(.signed, Int(N)) == Int(.signed, N)`
///   In general case.
/// - `ProductType(*const u32) == u32`
///   Remove pointer from pointer of number type.
pub fn ProductType(comptime ty: type) type {
    if (trait.isNumber(ty))
        return ty;
    if (trait.is(.Pointer)(ty) and trait.isNumber(meta.remove_pointer(ty)))
        return meta.remove_pointer(ty);
    @compileError("iter.ProductType: not defined: " ++ @typeName(ty));
    // TODO: support simd
    // if (std.meta.trait.is(.Vector)(ty))
    //     return ty;
}

comptime {
    assert(ProductType(i64) == i64);
    assert(ProductType(std.meta.Int(.signed, 32)) == std.meta.Int(.signed, 32));
    assert(ProductType(*const u32) == u32);
}

/// Define `Product` trait
///
/// # Details
/// Trait to represent types that can be created by multiplying elements of an iterator.
/// `Product` itself is not an iterator.
///
pub fn Product(comptime Item: type) type {
    return struct {
        pub fn product(iter: anytype) meta.Multiplyable.Output(Item) {
            return meta.Multiplyable.product(iter);
        }
    };
}

comptime {
    var arr1 = [_]u32{};
    var arr2 = [_]i64{};
    const I = struct {
        fn call(comptime T: type) type {
            return SliceIter(T);
        }
    }.call;
    assert(@TypeOf(Product(I(u32).Item).product(I(u32).new(arr1[0..]))) == u32);
    assert(@TypeOf(Product(I(i64).Item).product(I(i64).new(arr2[0..]))) == i64);
}

test "Product" {
    var arr = [_]u32{ 1, 1, 2, 3, 5, 8, 13, 21, 34 };
    const I = SliceIter(u32);
    try testing.expectEqual(@as(u32, 1), Product(I.Item).product(I.new(arr[5..5])));
    try testing.expectEqual(@as(u32, 6), Product(I.Item).product(I.new(arr[0..4])));
    try testing.expectEqual(@as(u32, 104), Product(I.Item).product(I.new(arr[5..7])));
}

/// Summation on an Iterator
///
/// # Details
/// Trait to represent types that can be created by summing up an iterator.
/// `Sum` itself is not an iterator.
///
pub fn Sum(comptime Item: type) type {
    return struct {
        pub fn sum(iter: anytype) meta.Sumable.Output(Item) {
            return meta.Sumable.sum(iter);
        }
    };
}

comptime {
    var arr1 = [_]u32{};
    var arr2 = [_]i64{};
    const I = SliceIter;
    assert(@TypeOf(Sum(I(u32).Item).sum(I(u32).new(arr1[0..]))) == u32);
    assert(@TypeOf(Sum(I(i64).Item).sum(I(i64).new(arr2[0..]))) == i64);
}

test "Sum" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const I = SliceIter(u32);
    try testing.expectEqual(@as(u32, 0), Sum(I.Item).sum(I.new(arr[0..0])));
    try testing.expectEqual(@as(u32, 15), Sum(I.Item).sum(I.new(arr[0..5])));
    try testing.expectEqual(@as(u32, 36), Sum(I.Item).sum(I.new(arr[0..8])));
    try testing.expectEqual(@as(u32, 55), Sum(I.Item).sum(I.new(arr[0..])));
}

pub fn MakeFlatten(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.isIterator(Iter.Item));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        curr: ?Iter.Item,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter, .curr = null };
        }

        pub fn next(self: *Self) ?Item {
            if (self.curr == null)
                self.curr = self.iter.next();
            while (self.curr) |_| : (self.curr = self.iter.next()) {
                if (self.curr.?.next()) |curr| {
                    return curr;
                }
            }
            return null;
        }
    };
}

pub fn Flatten(comptime Iter: type) type {
    return MakeFlatten(derive.Derive, Iter);
}

comptime {
    const Range = range.RangeIter;
    assert(Flatten(IterMap(Range(u32), fn (u32) Range(u32))).Self == Flatten(IterMap(Range(u32), fn (u32) Range(u32))));
    assert(Flatten(IterMap(Range(u32), fn (u32) Range(u32))).Item == u32);
    assert(meta.isIterator(Flatten(IterMap(Range(u32), fn (u32) Range(u32)))));
}

test "Flatten" {
    const Range = range.RangeIter;
    const Gen = struct {
        fn call(x: u32) Range(u32) {
            return Range(u32).new(@as(u32, 0), x, 1);
        }
    };
    const Iter = Flatten(IterMap(Range(u32), fn (u32) Range(u32)));
    var iter = Iter.new(IterMap(Range(u32), fn (u32) Range(u32))
        .new(Gen.call, Range(u32).new(@as(u32, 1), 4, 1)));

    // range(0, 1)
    try testing.expectEqual(@as(?u32, 0), iter.next());
    // range(0, 2)
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    // range(0, 3)
    try testing.expectEqual(@as(?u32, 0), iter.next());
    try testing.expectEqual(@as(?u32, 1), iter.next());
    try testing.expectEqual(@as(?u32, 2), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
}

pub fn MakeIterMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    comptime assert(meta.isIterator(Iter));

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
            if (self.iter.next()) |item| {
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
        pub fn call(value: *const u32) bool {
            return value.* % 2 == 0;
        }
    };
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    var arr_iter = ArrayIter(u32, arr.len).new(&arr);
    var iter = IterFilter(ArrayIter(u32, arr.len), fn (*const u32) bool).new(IsEven.call, arr_iter);
    try testing.expectEqual(@as(?*u32, null), iter.next());
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());
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
            if (self.iter.next()) |item| {
                if (self.f(item)) |v| {
                    return v;
                }
            }
            return null;
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
        pub fn call(value: *const []const u8) ?u32 {
            return std.fmt.parseInt(u32, value.*, 10) catch null;
        }
    };
    var arr = [_][]const u8{ "abc", "123", "345", "-123.", "1abc" };
    var arr_iter = ArrayIter([]const u8, arr.len).new(&arr);
    var iter = FilterMap(ArrayIter([]const u8, arr.len), fn (*const []const u8) ?u32).new(ParseInt.call, arr_iter);
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(u32, 123), iter.next().?);
    try testing.expectEqual(@as(u32, 345), iter.next().?);
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, null), iter.next());
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

pub fn MakeEnumerate(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Tuple2(Iter.Item, usize);
        pub usingnamespace D(@This());

        iter: Iter,
        count: usize,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter, .count = 0 };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |v| {
                const count = self.count;
                self.count += 1;
                return tuple.tuple2(v, count);
            } else {
                return null;
            }
        }
    };
}

pub fn Enumerate(comptime Iter: type) type {
    return MakeEnumerate(derive.Derive, Iter);
}

comptime {
    assert(Enumerate(SliceIter(u32)).Self == Enumerate(SliceIter(u32)));
    assert(Enumerate(SliceIter(u32)).Item == Tuple2(SliceIter(u32).Item, usize));
    assert(meta.isIterator(Enumerate(SliceIter(u32))));
}

test "Enumerate" {
    var arr = [_][]const u8{ "foo", "bar", "bazz" };
    var siter = SliceIter([]const u8).new(arr[0..]);
    const Iter = Enumerate(@TypeOf(siter));
    var iter = Enumerate(@TypeOf(siter)).new(siter);
    try testing.expectEqual(tuple.tuple2(&arr[0], @as(usize, 0)), iter.next().?);
    try testing.expectEqual(tuple.tuple2(&arr[1], @as(usize, 1)), iter.next().?);
    try testing.expectEqual(tuple.tuple2(&arr[2], @as(usize, 2)), iter.next().?);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeTake(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        take: usize,

        pub fn new(iter: Iter, take: usize) Self {
            return .{ .iter = iter, .take = take };
        }

        pub fn next(self: *Self) ?Item {
            if (0 < self.take) {
                self.take -= 1;
                return self.iter.next();
            } else {
                return null;
            }
        }
    };
}

pub fn Take(comptime Iter: type) type {
    return MakeTake(derive.Derive, Iter);
}

comptime {
    assert(Take(SliceIter(u32)).Self == Take(SliceIter(u32)));
    assert(Take(SliceIter(u32)).Item == SliceIter(u32).Item);
    assert(meta.isIterator(Take(SliceIter(u32))));
}

test "Take" {
    var arr = [_]i32{ 3, 2, 1, 0, 1, 2, 3 };
    var siter = SliceIter(i32).new(arr[0..]);
    const Iter = Take(@TypeOf(siter));
    var iter = Iter.new(siter, 4);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(i32, 2), iter.next().?.*);
    try testing.expectEqual(@as(i32, 1), iter.next().?.*);
    try testing.expectEqual(@as(i32, 0), iter.next().?.*);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

test "Take sequence small than 'n'" {
    var arr = [_]i32{ 3, 2, 1 };
    var siter = SliceIter(i32).new(arr[0..]);
    const Iter = Take(@TypeOf(siter));
    var iter = Iter.new(siter, 4);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(i32, 2), iter.next().?.*);
    try testing.expectEqual(@as(i32, 1), iter.next().?.*);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeTakeWhile(comptime D: fn (type) type, comptime Iter: type, comptime P: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        pred: P,
        take: bool,

        pub fn new(iter: Iter, pred: P) Self {
            return .{ .iter = iter, .pred = pred, .take = true };
        }

        pub fn next(self: *Self) ?Item {
            if (self.take) {
                if (self.iter.next()) |v| {
                    if (self.pred(&v))
                        return v;
                }
                self.take = false;
            }
            return null;
        }
    };
}

pub fn TakeWhile(comptime Iter: type, comptime P: type) type {
    return MakeTakeWhile(derive.Derive, Iter, P);
}

comptime {
    assert(TakeWhile(SliceIter(u32), fn (*const *u32) bool).Self == TakeWhile(SliceIter(u32), fn (*const *u32) bool));
    assert(TakeWhile(SliceIter(u32), fn (*const *u32) bool).Item == SliceIter(u32).Item);
    assert(meta.isIterator(TakeWhile(SliceIter(u32), fn (*const *u32) bool)));
}

test "TakeWhile" {
    var arr = [_]i32{ 3, 2, 1, 0, 1, 2, 3 };
    var siter = SliceIter(i32).new(arr[0..]);
    const Iter = TakeWhile(@TypeOf(siter), fn (*const *i32) bool);
    var iter = Iter.new(siter, struct {
        fn call(v: *const *i32) bool {
            return v.*.* > 0;
        }
    }.call);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(i32, 2), iter.next().?.*);
    try testing.expectEqual(@as(i32, 1), iter.next().?.*);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeSkip(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        skip: usize,

        pub fn new(iter: Iter, skip: usize) Self {
            return .{ .iter = iter, .skip = skip };
        }

        pub fn next(self: *Self) ?Item {
            while (0 < self.skip) : (self.skip -= 1) {
                // TODO: destroy if the aquired value is owned
                _ = self.iter.next();
            }
            return self.iter.next();
        }
    };
}

pub fn Skip(comptime Iter: type) type {
    return MakeSkip(derive.Derive, Iter);
}

comptime {
    assert(Skip(SliceIter(u32)).Self == Skip(SliceIter(u32)));
    assert(Skip(SliceIter(u32)).Item == SliceIter(u32).Item);
    assert(meta.isIterator(Skip(SliceIter(u32))));
}

test "Skip" {
    var arr = [_]i32{ 3, 2, 1, 0, -1, 2, 3 };
    var siter = SliceIter(i32).new(arr[0..]);
    const Iter = Skip(@TypeOf(siter));
    var iter = Iter.new(siter, 3);
    try testing.expectEqual(@as(i32, 0), iter.next().?.*);
    try testing.expectEqual(@as(i32, -1), iter.next().?.*);
    try testing.expectEqual(@as(i32, 2), iter.next().?.*);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeSkipWhile(comptime D: fn (type) type, comptime Iter: type, comptime P: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        pred: P,
        skip: bool,

        pub fn new(iter: Iter, pred: P) Self {
            return .{ .iter = iter, .pred = pred, .skip = true };
        }

        pub fn next(self: *Self) ?Item {
            if (self.skip) {
                while (self.iter.next()) |v| {
                    if (self.pred(&v)) {
                        continue;
                    } else {
                        self.skip = false;
                        return v;
                    }
                }
                self.skip = false;
            }
            return self.iter.next();
        }
    };
}

pub fn SkipWhile(comptime Iter: type, comptime P: type) type {
    return MakeSkipWhile(derive.Derive, Iter, P);
}

comptime {
    assert(SkipWhile(SliceIter(u32), fn (*const *u32) bool).Self == SkipWhile(SliceIter(u32), fn (*const *u32) bool));
    assert(SkipWhile(SliceIter(u32), fn (*const *u32) bool).Item == SliceIter(u32).Item);
    assert(meta.isIterator(SkipWhile(SliceIter(u32), fn (*const *u32) bool)));
}

test "SkipWhile" {
    var arr = [_]i32{ 3, 2, 1, 0, -1, 2, 3 };
    var siter = SliceIter(i32).new(arr[0..]);
    const Iter = SkipWhile(@TypeOf(siter), fn (*const *i32) bool);
    var iter = Iter.new(siter, struct {
        fn call(v: *const *i32) bool {
            return v.*.* > 0;
        }
    }.call);
    try testing.expectEqual(@as(i32, 0), iter.next().?.*);
    try testing.expectEqual(@as(i32, -1), iter.next().?.*);
    try testing.expectEqual(@as(i32, 2), iter.next().?.*);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeInspect(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        func: fn (*const Iter.Item) void,

        pub fn new(iter: Iter, func: fn (*const Iter.Item) void) Self {
            return .{ .iter = iter, .func = func };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                self.func(&val);
                return val;
            }
            return null;
        }
    };
}

pub fn Inspect(comptime Iter: type) type {
    return MakeInspect(derive.Derive, Iter);
}

comptime {
    assert(Inspect(SliceIter(u32)).Self == Inspect(SliceIter(u32)));
    assert(Inspect(SliceIter(u32)).Item == SliceIter(u32).Item);
    assert(meta.isIterator(Inspect(SliceIter(u32))));
}

test "Inspect" {
    // The function 'call' cannot access to out of namespace
    // if it's type is to be 'Fn' rather than 'BoundFn'.
    try (struct {
        var i: u32 = 0;
        fn call(x: *const *i32) void {
            _ = x;
            i += 1;
        }
        fn dotest(self: @This()) !void {
            _ = self;
            var arr = [_]i32{ 3, 1, 0, -1, -2, 3 };
            var siter = SliceIter(i32).new(arr[0..]);
            const Iter = Inspect(@TypeOf(siter));
            var iter = Iter.new(siter, call);

            try testing.expectEqual(@as(i32, 3), iter.next().?.*);
            try testing.expectEqual(@as(u32, 1), i);
            try testing.expectEqual(@as(i32, 1), iter.next().?.*);
            try testing.expectEqual(@as(u32, 2), i);
            try testing.expectEqual(@as(i32, 0), iter.next().?.*);
            try testing.expectEqual(@as(u32, 3), i);
            try testing.expectEqual(@as(i32, -1), iter.next().?.*);
            try testing.expectEqual(@as(u32, 4), i);
            try testing.expectEqual(@as(i32, -2), iter.next().?.*);
            try testing.expectEqual(@as(u32, 5), i);
            try testing.expectEqual(@as(i32, 3), iter.next().?.*);
            try testing.expectEqual(@as(u32, 6), i);
            try testing.expectEqual(@as(?Iter.Item, null), iter.next());
            try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        }
    }{}).dotest();
}

pub fn MakeMapWhile(comptime F: fn (type) type, comptime I: type, comptime P: type) type {
    comptime assert(meta.isIterator(I));
    comptime assertEqualTuple(Tuple1(I.Item).StdTuple, domain(P));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(codomain(P));
        pub usingnamespace F(@This());

        iter: I,
        pred: P,

        pub fn new(iter: I, pred: P) Self {
            return .{ .iter = iter, .pred = pred };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.iter.next()) |val| {
                if (self.pred(val)) |pval| {
                    return pval;
                } else {
                    return null;
                }
            }
            return null;
        }
    };
}

pub fn MapWhile(comptime I: type, comptime P: type) type {
    return MakeMapWhile(derive.Derive, I, P);
}

comptime {
    assert(MapWhile(ArrayIter(u32, 3), fn (*u32) ?[]const u8).Self == MapWhile(ArrayIter(u32, 3), fn (*u32) ?[]const u8));
    assert(MapWhile(ArrayIter(u32, 3), fn (*u32) ?[]const u8).Item == []const u8);
    assert(meta.isIterator(MapWhile(ArrayIter(u32, 3), fn (*u32) ?[]const u8)));
}

test "MapWhile" {
    var arr = [_][]const u8{ "1", "2abc", "3" };
    const Iter = ArrayIter([]const u8, arr.len);
    var iter = MapWhile(Iter, fn (*[]const u8) ?u32)
        .new(Iter.new(&arr), struct {
        fn call(buf: *[]const u8) ?u32 {
            return std.fmt.parseInt(u32, buf.*, 10) catch null;
        }
    }.call);
    try testing.expectEqual(@as(?u32, 1), iter.next().?);
    try testing.expectEqual(@as(?u32, null), iter.next());
    try testing.expectEqual(@as(?u32, 3), iter.next().?);
    try testing.expectEqual(@as(?u32, null), iter.next());
}

pub fn MakeStepBy(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        step_by: usize,

        pub fn new(iter: Iter, step_by: usize) Self {
            assert(0 < step_by);
            return .{ .iter = iter, .step_by = step_by };
        }

        pub fn next(self: *Self) ?Item {
            var step = self.step_by - 1;
            var item = self.iter.next();
            while (0 < step) : (step -= 1) {
                // TODO: destroy if the aquired value is owned
                _ = self.iter.next();
            }
            return item;
        }
    };
}

pub fn StepBy(comptime Iter: type) type {
    return MakeStepBy(derive.Derive, Iter);
}

comptime {
    assert(StepBy(SliceIter(u32)).Self == StepBy(SliceIter(u32)));
    assert(StepBy(SliceIter(u32)).Item == SliceIter(u32).Item);
    assert(meta.isIterator(StepBy(SliceIter(u32))));
}

test "StepBy" {
    var arr = [_]i32{ 3, 2, 1, 0, -1, 2, 3, 4 };
    var siter = SliceIter(i32).new(arr[0..]);
    const Iter = StepBy(@TypeOf(siter));
    var iter = Iter.new(siter, 3);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(i32, 0), iter.next().?.*);
    try testing.expectEqual(@as(i32, 3), iter.next().?.*);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeScan(comptime D: fn (type) type, comptime Iter: type, comptime St: type, comptime F: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.equalTuple(Tuple2(*St, Iter.Item).StdTuple, domain(F)));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(codomain(F));
        pub usingnamespace D(@This());

        iter: Iter,
        state: St,
        f: F,

        pub fn new(iter: Iter, initial_state: St, f: F) Self {
            return .{ .iter = iter, .state = initial_state, .f = f };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return self.f(&self.state, val);
            } else {
                return null;
            }
        }
    };
}

pub fn Scan(comptime Iter: type, comptime St: type, comptime F: type) type {
    return MakeScan(derive.Derive, Iter, St, F);
}

comptime {
    const St = std.ArrayList(u32);
    assert(Scan(SliceIter(u32), St, fn (*St, *u32) ?[]const u8).Self == Scan(SliceIter(u32), St, fn (*St, *u32) ?[]const u8));
    assert(Scan(SliceIter(u32), St, fn (*St, *u32) ?[]const u8).Item == []const u8);
    assert(meta.isIterator(Scan(SliceIter(u32), St, fn (*St, *u32) ?[]const u8)));
}

test "Scan" {
    var arr = [_][]const u8{ "32", "4", "0", "abc", "2", "def", "3" };
    var siter = SliceIter([]const u8).new(arr[0..]);
    const Iter = Scan(@TypeOf(siter), i32, fn (*i32, *[]const u8) ?i32);
    var iter = Iter.new(siter, @as(i32, 1), struct {
        fn call(st: *i32, v: *[]const u8) ?i32 {
            if (std.fmt.parseInt(i32, v.*, 10) catch null) |val| {
                if (st.* == 0) {
                    st.* = val;
                } else {
                    st.* *= val;
                }
                return st.*;
            } else {
                return null;
            }
        }
    }.call);
    try testing.expectEqual(@as(i32, 32), iter.next().?);
    try testing.expectEqual(@as(i32, 128), iter.next().?);
    try testing.expectEqual(@as(i32, 0), iter.next().?);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(i32, 2), iter.next().?);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(i32, 6), iter.next().?);
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    try testing.expectEqual(@as(?Iter.Item, null), iter.next());
}

pub fn MakeFuse(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        iter: Iter,
        // 'null' has been occurred
        none: bool,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter, .none = false };
        }

        pub fn next(self: *Self) ?Item {
            if (self.none)
                return null;
            if (self.iter.next()) |val| {
                return val;
            } else {
                self.none = true;
                return null;
            }
        }
    };
}

pub fn Fuse(comptime Iter: type) type {
    return MakeFuse(derive.Derive, Iter);
}

comptime {
    assert(Fuse(SliceIter(u32)).Self == Fuse(SliceIter(u32)));
    assert(Fuse(SliceIter(u32)).Item == SliceIter(u32).Item);
    assert(meta.isIterator(Fuse(SliceIter(u32))));
}

test "Fuse" {
    const Divisor = struct {
        pub const Self: type = @This();
        pub const Item: type = u32;
        val: u32,
        div: u32,
        fn next(self: *Self) ?Item {
            if (self.val <= self.div or self.val % self.div == 0) {
                const val = self.val;
                self.val += 1;
                return val;
            } else {
                self.val += 1;
                return null;
            }
        }
    };
    {
        const Iter = Divisor;
        var iter = Divisor{ .val = 0, .div = 2 };
        try testing.expectEqual(@as(u32, 0), iter.next().?);
        try testing.expectEqual(@as(u32, 1), iter.next().?);
        try testing.expectEqual(@as(u32, 2), iter.next().?);
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        try testing.expectEqual(@as(u32, 4), iter.next().?);
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        try testing.expectEqual(@as(u32, 6), iter.next().?);
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    }
    {
        const Iter = Fuse(Divisor);
        var iter = Iter.new(.{ .val = 0, .div = 2 });
        try testing.expectEqual(@as(u32, 0), iter.next().?);
        try testing.expectEqual(@as(u32, 1), iter.next().?);
        try testing.expectEqual(@as(u32, 2), iter.next().?);
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
        try testing.expectEqual(@as(?Iter.Item, null), iter.next());
    }
}
