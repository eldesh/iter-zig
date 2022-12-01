const std = @import("std");
const to_iter = @import("./to_iter.zig");
const derive = @import("./derive.zig");
const meta = @import("./meta.zig");
const tuple = @import("./tuple.zig");
const range = @import("./range.zig");

const trait = std.meta.trait;
const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;
const assertEqualTupleType = meta.assertEqualTupleType;
const debug = std.debug.print;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
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

pub fn func_arity(comptime F: type) usize {
    comptime assert(is_func_type(F));
    return @typeInfo(F).Fn.args.len;
}

pub fn is_unary_func_type(comptime F: type) bool {
    return trait.is(.Fn)(F) and @typeInfo(F).Fn.args.len == 1;
}

pub fn is_binary_func_type(comptime F: type) bool {
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
    assertEqualTupleType(domain(fn (u32) u16), Tuple1(u32).StdTuple);
    assert(codomain(fn (u32) u16) == u16);
    assertEqualTupleType(domain(fn (u32) []const u8), Tuple1(u32).StdTuple);
    assert(codomain(fn (u32) []const u8) == []const u8);
}

pub fn MakePeekable(comptime D: fn (type) type, comptime Iter: type) type {
    comptime {
        assert(meta.isIterator(Iter));
        if (meta.basis.isPartialEq(*const Iter.Item)) {
            return struct {
                pub const Self: type = @This();
                pub const Item: type = Iter.Item;
                pub usingnamespace D(@This());

                iter: Iter,
                peeked: ?Iter.Item,

                pub fn new(iter: Iter) Self {
                    var it = iter;
                    const peeked = it.next();
                    return .{ .iter = it, .peeked = peeked };
                }

                pub fn peek(self: *Self) ?*const Item {
                    return self.peek_mut();
                }

                pub fn peek_mut(self: *Self) ?*Item {
                    if (self.peeked) |*val|
                        return val;
                    return null;
                }

                pub fn next_if(self: *Self, func: fn (*const Item) bool) ?Item {
                    if (self.peek()) |peeked| {
                        // if and only if the func() returns true for the next value, it is consumed.
                        if (func(peeked))
                            return self.next();
                    }
                    return null;
                }

                // derive `next_if_eq` inplace
                pub fn next_if_eq(self: *Self, expected: *const Item) ?Item {
                    if (self.peek()) |peeked| {
                        // if and only if the `peeked` value is equals to `expected`, it is consumed.
                        if (meta.basis.PartialEq.eq(peeked, expected))
                            return self.next();
                    }
                    return null;
                }

                pub fn next(self: *Self) ?Item {
                    const peeked = self.peeked;
                    self.peeked = self.iter.next();
                    return peeked;
                }
            };
        } else {
            return struct {
                pub const Self: type = @This();
                pub const Item: type = Iter.Item;
                pub usingnamespace D(@This());

                iter: Iter,
                peeked: ?Iter.Item,

                pub fn new(iter: Iter) Self {
                    var it = iter;
                    const peeked = it.next();
                    return .{ .iter = it, .peeked = peeked };
                }

                pub fn peek(self: *Self) ?*const Item {
                    return self.peek_mut();
                }

                pub fn peek_mut(self: *Self) ?*Item {
                    if (self.peeked) |*val|
                        return val;
                    return null;
                }

                pub fn next_if(self: *Self, func: fn (*const Item) bool) ?Item {
                    if (self.peek()) |peeked| {
                        // if and only if the func() returns true for the next value, it is consumed.
                        if (func(peeked))
                            return self.next();
                    }
                    return null;
                }

                pub fn next(self: *Self) ?Item {
                    const peeked = self.peeked;
                    self.peeked = self.iter.next();
                    return peeked;
                }
            };
        }
    }
}

pub fn Peekable(comptime Iter: type) type {
    return MakePeekable(derive.DeriveIterator, Iter);
}

comptime {
    const Range = range.Range;
    assert(Peekable(Range(u32)).Self == Peekable(Range(u32)));
    assert(Peekable(Range(u32)).Item == u32);
}

test "Peekable" {
    const Range = range.Range;
    const Iter = Peekable(Range(u32));
    {
        var peek = Iter.new(Range(u32).new(@as(u32, 1), 4));
        try testing.expectEqual(@as(u32, 1), peek.peek().?.*);
        try testing.expectEqual(@as(?u32, 1), peek.next());

        try testing.expectEqual(@as(?u32, 2), peek.next());

        try testing.expectEqual(@as(u32, 3), peek.peek().?.*);
        try testing.expectEqual(@as(u32, 3), peek.peek().?.*);

        try testing.expectEqual(@as(?u32, 3), peek.next());

        try testing.expectEqual(@as(?*const u32, null), peek.peek());
        try testing.expectEqual(@as(?u32, null), peek.next());
    }
    {
        var peek = Iter.new(Range(u32).new(@as(u32, 1), 4));
        try comptime testing.expectEqual(?*u32, @TypeOf(peek.peek_mut()));
        try testing.expectEqual(@as(u32, 1), peek.peek_mut().?.*);
        try testing.expectEqual(@as(u32, 1), peek.peek_mut().?.*);
        try testing.expectEqual(@as(?u32, 1), peek.next());
        if (peek.peek_mut()) |p| {
            try testing.expectEqual(p.*, 2);
            p.* = 5;
        }
        try testing.expectEqual(@as(?u32, 5), peek.next());
        try testing.expectEqual(@as(?u32, 3), peek.next());
        try testing.expectEqual(@as(?u32, null), peek.next());
    }
    {
        var peek = Iter.new(Range(u32).new(@as(u32, 0), 6));
        try testing.expectEqual(@as(?u32, 0), peek.next_if(struct {
            fn f(x: *const u32) bool {
                return x.* == 0;
            }
        }.f));
        try testing.expectEqual(@as(?u32, null), peek.next_if(struct {
            fn f(x: *const u32) bool {
                return x.* == 0;
            }
        }.f));
        try testing.expectEqual(@as(?u32, 1), peek.next());
    }
    {
        var peek = Iter.new(Range(u32).new(@as(u32, 0), 6));
        var zero: u32 = 0;
        try testing.expectEqual(@as(?u32, 0), peek.next_if_eq(&zero));
        try testing.expectEqual(@as(?u32, null), peek.next_if_eq(&zero));
        try testing.expectEqual(@as(?u32, 1), peek.next());
    }
}

pub fn MakeCycle(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.basis.isClonable(Iter));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Iter.Item;
        pub usingnamespace D(@This());

        orig: Iter,
        iter: Iter,

        pub fn new(iter: Iter) Self {
            return .{ .orig = iter, .iter = meta.basis.Clone.clone(iter) catch unreachable };
        }

        pub fn next(self: *Self) ?Item {
            var fst_elem = false;
            while (true) : (self.iter = meta.basis.Clone.clone(self.orig) catch unreachable) {
                if (self.iter.next()) |val| {
                    return val;
                }
                if (fst_elem)
                    return null;
                fst_elem = true;
            }
            unreachable;
        }
    };
}

pub fn Cycle(comptime Iter: type) type {
    return MakeCycle(derive.DeriveIterator, Iter);
}

comptime {
    const Range = range.Range;
    assert(Cycle(Range(u32)).Self == Cycle(Range(u32)));
    assert(Cycle(Range(u32)).Item == u32);
}

test "Cycle" {
    const Range = range.Range;
    const Iter = Cycle(Range(u32));
    {
        var cycle = Iter.new(range.range(@as(u32, 1), 4));
        try testing.expectEqual(@as(?u32, 1), cycle.next());
        try testing.expectEqual(@as(?u32, 2), cycle.next());
        try testing.expectEqual(@as(?u32, 3), cycle.next());
        try testing.expectEqual(@as(?u32, 1), cycle.next());
        try testing.expectEqual(@as(?u32, 2), cycle.next());
        try testing.expectEqual(@as(?u32, 3), cycle.next());
        try testing.expectEqual(@as(?u32, 1), cycle.next());
        try testing.expectEqual(@as(?u32, 2), cycle.next());
        try testing.expectEqual(@as(?u32, 3), cycle.next());
    }
    {
        var cycle = Iter.new(range.range(@as(u32, 1), 1));
        try testing.expectEqual(@as(?u32, null), cycle.next());
        try testing.expectEqual(@as(?u32, null), cycle.next());
        try testing.expectEqual(@as(?u32, null), cycle.next());
        try testing.expectEqual(@as(?u32, null), cycle.next());
    }
}

pub fn MakeCopied(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.basis.isCopyable(Iter.Item));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.deref_type(Iter.Item);
        pub usingnamespace D(@This());

        iter: Iter,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return if (comptime trait.isSingleItemPtr(Iter.Item)) val.* else val;
            }
            return null;
        }
    };
}

pub fn Copied(comptime Iter: type) type {
    return MakeCopied(derive.DeriveIterator, Iter);
}

comptime {
    const I = SliceIter;
    assert(Copied(I(u32)).Self == Copied(I(u32)));
    assert(Copied(I(u32)).Item == u32);
}

test "Copied" {
    const Slice = SliceIter;
    const Iter = Copied(Slice(u32));
    var arr = [_]u32{ 0, 1, 2, 3 };
    var copied = Iter.new(Slice(u32).new(arr[0..]));

    try testing.expectEqual(@as(?Iter.Item, 0), copied.next());
    try testing.expectEqual(@as(?Iter.Item, 1), copied.next());
    try testing.expectEqual(@as(?Iter.Item, 2), copied.next());
    try testing.expectEqual(@as(?Iter.Item, 3), copied.next());
    try testing.expectEqual(@as(?Iter.Item, null), copied.next());
}

pub fn MakeCloned(comptime D: fn (type) type, comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(meta.basis.isClonable(Iter.Item));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.basis.Clone.ResultType(Iter.Item);
        pub usingnamespace D(@This());

        iter: Iter,

        pub fn new(iter: Iter) Self {
            return .{ .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |val| {
                return meta.basis.Clone.clone(val);
            }
            return null;
        }
    };
}

pub fn Cloned(comptime Iter: type) type {
    return MakeCloned(derive.DeriveIterator, Iter);
}

comptime {
    const I = SliceIter;
    assert(Cloned(I(u32)).Self == Cloned(I(u32)));
    assert(Cloned(I(u32)).Item == meta.basis.Clone.ResultType(*u32));
}

test "Clone" {
    const Slice = SliceIter;
    const Iter = Cloned(Slice(u32));
    var arr = [_]u32{ 0, 1, 2, 3 };
    var cloned = Iter.new(Slice(u32).new(arr[0..]));

    try testing.expectEqual(@as(Iter.Item, 0), cloned.next().?);
    try testing.expectEqual(@as(Iter.Item, 1), cloned.next().?);
    try testing.expectEqual(@as(Iter.Item, 2), cloned.next().?);
    try testing.expectEqual(@as(Iter.Item, 3), cloned.next().?);
    try testing.expectEqual(@as(?Iter.Item, null), cloned.next());
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
    return MakeZip(derive.DeriveIterator, Iter, Other);
}

comptime {
    const I = SliceIter;
    assert(Zip(I(u32), I(u32)).Self == Zip(I(u32), I(u32)));
    assert(Zip(I(u32), I(u32)).Item == tuple.Tuple2(*u32, *u32));
}

test "Zip" {
    const str = []const u8;
    const I = SliceIter;
    const R = range.Range;
    const Iter = Zip(I(str), R(u32));
    var arr = [_]str{ "foo", "bar", "buzz" };
    var zip = Iter.new(I(str).new(arr[0..]), range.range(@as(u32, 2), 10));

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
    return MakeFlatMap(derive.DeriveIterator, Iter, F, U);
}

comptime {
    const I = SliceIter;
    assert(FlatMap(I(I(u32)), fn (*I(u32)) I(u32), I(u32)).Self ==
        FlatMap(I(I(u32)), fn (*I(u32)) I(u32), I(u32)));
    assert(FlatMap(I(I(u32)), fn (*I(u32)) I(u32), I(u32)).Item == *u32);
}

test "FlatMap" {
    const I = SliceIter;
    const R = range.Range;
    const Iter = FlatMap(I(u32), fn (*u32) R(u32), R(u32));
    var arr = [_]u32{ 2, 3, 4 };
    var iter = Iter.new(I(u32).new(arr[0..]), struct {
        fn call(i: *const u32) R(u32) {
            return range.range(@as(u32, 0), i.*);
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
    comptime assert(meta.basis.isPartialOrd(Item));
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
                    if (meta.basis.PartialOrd.partial_cmp(lval, rval)) |ord| {
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
    comptime assert(meta.basis.isOrd(Item));
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
                    const ord = meta.basis.Ord.cmp(lval, rval);
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
    return MakeFlatten(derive.DeriveIterator, Iter);
}

comptime {
    const Range = range.Range;
    assert(Flatten(Map(Range(u32), fn (u32) Range(u32))).Self == Flatten(Map(Range(u32), fn (u32) Range(u32))));
    assert(Flatten(Map(Range(u32), fn (u32) Range(u32))).Item == u32);
    assert(meta.isIterator(Flatten(Map(Range(u32), fn (u32) Range(u32)))));
}

test "Flatten" {
    const Range = range.Range;
    const Gen = struct {
        fn call(x: u32) Range(u32) {
            return Range(u32).new(@as(u32, 0), x);
        }
    };
    const Iter = Flatten(Map(Range(u32), fn (u32) Range(u32)));
    var iter = Iter.new(Map(Range(u32), fn (u32) Range(u32))
        .new(Gen.call, Range(u32).new(@as(u32, 1), 4)));

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

pub fn MakeMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
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

pub fn Map(comptime Iter: type, comptime F: type) type {
    return MakeMap(derive.DeriveIterator, Iter, F);
}

comptime {
    assert(Map(SliceIter(u32), fn (*const u32) []u8).Self == Map(SliceIter(u32), fn (*const u32) []u8));
    assert(Map(SliceIter(u32), fn (*const u32) []u8).Item == []u8);
    assert(meta.isIterator(Map(SliceIter(u32), fn (*const u32) []u8)));
}

test "Map" {
    const Square = struct {
        pub fn f(v: *const u32) u64 {
            return v.* * v.*;
        }
    };
    var arr = [_]u32{ 1, 2, 3 };
    var arr_iter = ArrayIter(u32, arr.len).new(&arr);
    var iter = Map(ArrayIter(u32, arr.len), fn (*const u32) u64).new(Square.f, arr_iter);
    try testing.expectEqual(@as(?u64, 1), iter.next());
    try testing.expectEqual(@as(?u64, 4), iter.next());
    try testing.expectEqual(@as(?u64, 9), iter.next());
    try testing.expectEqual(@as(?u64, null), iter.next());
}

pub fn MakeFilter(comptime D: fn (type) type, comptime Iter: type, comptime Pred: type) type {
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

pub fn Filter(comptime Iter: type, comptime Pred: type) type {
    return MakeFilter(derive.DeriveIterator, Iter, Pred);
}

comptime {
    assert(Filter(SliceIter(u32), fn (*u32) bool).Self == Filter(SliceIter(u32), fn (*u32) bool));
    assert(Filter(SliceIter(u32), fn (*u32) bool).Item == *u32);
    assert(meta.isIterator(Filter(SliceIter(u32), fn (*u32) bool)));
}

test "Filter" {
    const IsEven = struct {
        pub fn call(value: *const u32) bool {
            return value.* % 2 == 0;
        }
    };
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
    var arr_iter = ArrayIter(u32, arr.len).new(&arr);
    var iter = Filter(ArrayIter(u32, arr.len), fn (*const u32) bool).new(IsEven.call, arr_iter);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 6), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());
}

pub fn MakeFilterMap(comptime D: fn (type) type, comptime Iter: type, comptime F: type) type {
    comptime assert(meta.isIterator(Iter));
    comptime assert(is_unary_func_type(F));
    comptime assert(trait.is(.Optional)(codomain(F)));
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
                }
            }
            return null;
        }
    };
}

pub fn FilterMap(comptime Iter: type, comptime F: type) type {
    return MakeFilterMap(derive.DeriveIterator, Iter, F);
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
    return MakeChain(derive.DeriveIterator, Iter1, Iter2);
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
            }
            return null;
        }
    };
}

pub fn Enumerate(comptime Iter: type) type {
    return MakeEnumerate(derive.DeriveIterator, Iter);
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
            }
            return null;
        }
    };
}

pub fn Take(comptime Iter: type) type {
    return MakeTake(derive.DeriveIterator, Iter);
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
    return MakeTakeWhile(derive.DeriveIterator, Iter, P);
}

comptime {
    assert(TakeWhile(SliceIter(u32), fn (*const *u32) bool).Self == TakeWhile(SliceIter(u32), fn (*const *u32) bool));
    assert(TakeWhile(SliceIter(u32), fn (*const *u32) bool).Item == SliceIter(u32).Item);
    assert(TakeWhile(SliceIter(u32), fn (*const SliceIter(u32).Item) bool).Item == SliceIter(u32).Item);
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
    return MakeSkip(derive.DeriveIterator, Iter);
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
    return MakeSkipWhile(derive.DeriveIterator, Iter, P);
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
    return MakeInspect(derive.DeriveIterator, Iter);
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
    comptime assertEqualTupleType(Tuple1(I.Item).StdTuple, domain(P));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = std.meta.Child(codomain(P));
        pub usingnamespace F(@This());

        iter: I,
        pred: P,

        pub fn new(iter: I, pred: P) Self {
            return .{ .iter = iter, .pred = pred };
        }

        pub fn next(self: *Self) ?Item {
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
    return MakeMapWhile(derive.DeriveIterator, I, P);
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
    return MakeStepBy(derive.DeriveIterator, Iter);
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
    comptime assert(meta.eqTupleType(Tuple2(*St, Iter.Item).StdTuple, domain(F)));
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
    return MakeScan(derive.DeriveIterator, Iter, St, F);
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
    return MakeFuse(derive.DeriveIterator, Iter);
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
        pub fn next(self: *Self) ?Item {
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

/// An iterator that yields nothing
pub fn MakeEmpty(comptime D: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace D(@This());

        pub fn new() Self {
            return .{};
        }

        pub fn next(self: *Self) ?Item {
            _ = self;
            return null;
        }
    };
}

/// An iterator that yields nothing with derived functions by `derive.DeriveIterator`.
pub fn Empty(comptime T: type) type {
    return MakeEmpty(derive.DeriveIterator, T);
}

comptime {
    assert(meta.isIterator(Empty(void)));
    assert(Empty(void).Self == Empty(void));
    assert(Empty(void).Item == void);
    assert(meta.isIterator(Empty(u32)));
    assert(Empty(u32).Self == Empty(u32));
    assert(Empty(u32).Item == u32);
}

test "Empty" {
    const unit = struct {};
    try testing.expectEqual(@as(?u32, null), Empty(u32).new().next());
    try testing.expectEqual(@as(?f64, null), Empty(f64).new().next());
    try testing.expectEqual(@as(?void, null), Empty(void).new().next());
    try testing.expectEqual(@as(?unit, null), Empty(unit).new().next());
}

/// An iterator that yields an element exactly once.
pub fn MakeOnce(comptime D: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace D(@This());

        value: ?T,
        pub fn new(value: T) Self {
            return .{ .value = value };
        }

        pub fn next(self: *Self) ?Item {
            if (self.value) |value| {
                self.value = null;
                return value;
            }
            return null;
        }
    };
}

/// An iterator that yields an element exactly once.
/// This iterator is constructed from `ops.once`.
pub fn Once(comptime T: type) type {
    return MakeOnce(derive.DeriveIterator, T);
}

comptime {
    assert(meta.isIterator(Once(void)));
    assert(Once(void).Self == Once(void));
    assert(Once(void).Item == void);
    assert(meta.isIterator(Once(u32)));
    assert(Once(u32).Self == Once(u32));
    assert(Once(u32).Item == u32);
}

test "Once" {
    const unit = struct {};
    {
        var it = Once(u32).new(42);
        try testing.expectEqual(@as(?u32, 42), it.next());
        try testing.expectEqual(@as(?u32, null), it.next());
    }
    {
        var it = Once([]const u8).new("foo");
        try testing.expectEqualStrings("foo", it.next().?);
        try testing.expectEqual(@as(?[]const u8, null), it.next());
    }
    {
        var it = Once(void).new(void{});
        try testing.expectEqual(@as(?void, void{}), it.next());
        try testing.expectEqual(@as(?void, null), it.next());
    }
    {
        var it = Once(unit).new(unit{});
        try testing.expectEqual(@as(?unit, unit{}), it.next());
        try testing.expectEqual(@as(?unit, null), it.next());
    }
}

/// An iterator that repeatedly yields a certain element indefinitely.
pub fn MakeRepeat(comptime D: fn (type) type, comptime T: type) type {
    comptime assert(meta.basis.isClonable(T));
    return struct {
        pub const Self: type = @This();
        pub const Item: type = meta.basis.Clone.ResultType(T);
        pub usingnamespace D(@This());

        value: T,
        pub fn new(value: T) Self {
            return .{ .value = value };
        }

        pub fn next(self: *Self) ?Item {
            return meta.basis.Clone.clone(self.value);
        }
    };
}

/// An iterator that repeatedly yields a certain element indefinitely.
/// This iterator is constructed from `ops.repeat`.
pub fn Repeat(comptime T: type) type {
    return MakeRepeat(derive.DeriveIterator, T);
}

comptime {
    assert(meta.isIterator(Repeat(u32)));
    assert(Repeat(u32).Self == Repeat(u32));
    assert(Repeat(u32).Item == meta.basis.Clone.EmptyError!u32);
    assert(meta.isIterator(Repeat(*const u32)));
    assert(Repeat(*const u32).Self == Repeat(*const u32));
    assert(Repeat(*const u32).Item == meta.basis.Clone.EmptyError!u32);
}

test "Repeat" {
    {
        var it = Repeat(u32).new(42);
        try testing.expectEqual(@as(u32, 42), try it.next().?);
        try testing.expectEqual(@as(u32, 42), try it.next().?);
        try testing.expectEqual(@as(u32, 42), try it.next().?);
        // repeat() never returns null
        // try testing.expectEqual(@as(?u32, null), it.next());
    }
    {
        var it = Repeat([3]u32).new([3]u32{ 1, 2, 3 });
        try testing.expectEqual([3]u32{ 1, 2, 3 }, try it.next().?);
        try testing.expectEqual([3]u32{ 1, 2, 3 }, try it.next().?);
        try testing.expectEqual([3]u32{ 1, 2, 3 }, try it.next().?);
    }
    {
        // chops infinite sequence
        var it = Repeat(void).new(void{}).take(3);
        try testing.expectEqual(void{}, try it.next().?);
        try testing.expectEqual(void{}, try it.next().?);
        try testing.expectEqual(void{}, try it.next().?);
        try testing.expectEqual(@as(?meta.basis.Clone.EmptyError!void, null), it.next());
    }
}
