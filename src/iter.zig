const std = @import("std");

const prim = @import("./derive/prim.zig");
const derive = @import("./derive.zig");
const meta = @import("./meta.zig");
const tuple = @import("./tuple.zig");

const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;

// iterator converters for unit tests
const to_iter = struct {
    const make = @import("./to_iter/make.zig");
    fn MakeSliceIter(comptime F: fn (type) type, comptime T: type) type {
        comptime return make.MakeSliceIter(F, T);
    }

    fn SliceIter(comptime Item: type) type {
        comptime return make.MakeSliceIter(derive.DeriveIterator, Item);
    }

    fn ArrayIter(comptime Item: type, comptime N: usize) type {
        comptime return make.MakeArrayIter(derive.DeriveIterator, Item, N);
    }
};

const SliceIter = to_iter.SliceIter;
const ArrayIter = to_iter.ArrayIter;

// range iterators for unit tests
const range = struct {
    const make = @import("./range/make.zig");
    fn MakeRange(comptime F: fn (type) type, comptime T: type) type {
        comptime return make.MakeRange(F, T);
    }

    fn Range(comptime T: type) type {
        comptime return make.MakeRange(derive.DeriveIterator, T);
    }

    fn range(start: anytype, end: @TypeOf(start)) Range(@TypeOf(start)) {
        return Range(@TypeOf(start)).new(start, end);
    }
};

pub fn Peekable(comptime Iter: type) type {
    return prim.MakePeekable(derive.DeriveIterator, Iter);
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

pub fn Cycle(comptime Iter: type) type {
    return prim.MakeCycle(derive.DeriveIterator, Iter);
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

pub fn Copied(comptime Iter: type) type {
    return prim.MakeCopied(derive.DeriveIterator, Iter);
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

pub fn Cloned(comptime Iter: type) type {
    return prim.MakeCloned(derive.DeriveIterator, Iter);
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

pub fn Zip(comptime Iter: type, comptime Other: type) type {
    return prim.MakeZip(derive.DeriveIterator, Iter, Other);
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

pub fn FlatMap(comptime Iter: type, comptime F: type, comptime U: type) type {
    return prim.MakeFlatMap(derive.DeriveIterator, Iter, F, U);
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

pub fn Flatten(comptime Iter: type) type {
    return prim.MakeFlatten(derive.DeriveIterator, Iter);
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

pub fn Map(comptime Iter: type, comptime F: type) type {
    return prim.MakeMap(derive.DeriveIterator, Iter, F);
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

pub fn Filter(comptime Iter: type, comptime Pred: type) type {
    return prim.MakeFilter(derive.DeriveIterator, Iter, Pred);
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

pub fn FilterMap(comptime Iter: type, comptime F: type) type {
    return prim.MakeFilterMap(derive.DeriveIterator, Iter, F);
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

pub fn Chain(comptime Iter1: type, comptime Iter2: type) type {
    return prim.MakeChain(derive.DeriveIterator, Iter1, Iter2);
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

pub fn Enumerate(comptime Iter: type) type {
    return prim.MakeEnumerate(derive.DeriveIterator, Iter);
}

comptime {
    assert(Enumerate(SliceIter(u32)).Self == Enumerate(SliceIter(u32)));
    assert(Enumerate(SliceIter(u32)).Item == tuple.Tuple2(SliceIter(u32).Item, usize));
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

pub fn Take(comptime Iter: type) type {
    return prim.MakeTake(derive.DeriveIterator, Iter);
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

pub fn TakeWhile(comptime Iter: type, comptime P: type) type {
    return prim.MakeTakeWhile(derive.DeriveIterator, Iter, P);
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

pub fn Skip(comptime Iter: type) type {
    return prim.MakeSkip(derive.DeriveIterator, Iter);
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

pub fn SkipWhile(comptime Iter: type, comptime P: type) type {
    return prim.MakeSkipWhile(derive.DeriveIterator, Iter, P);
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

pub fn Inspect(comptime Iter: type) type {
    return prim.MakeInspect(derive.DeriveIterator, Iter);
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

pub fn MapWhile(comptime I: type, comptime P: type) type {
    return prim.MakeMapWhile(derive.DeriveIterator, I, P);
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

pub fn StepBy(comptime Iter: type) type {
    return prim.MakeStepBy(derive.DeriveIterator, Iter);
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

pub fn Scan(comptime Iter: type, comptime St: type, comptime F: type) type {
    return prim.MakeScan(derive.DeriveIterator, Iter, St, F);
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

pub fn Fuse(comptime Iter: type) type {
    return prim.MakeFuse(derive.DeriveIterator, Iter);
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

/// An iterator that yields nothing with derived functions by `derive.DeriveIterator`.
pub fn Empty(comptime T: type) type {
    return prim.MakeEmpty(derive.DeriveIterator, T);
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
/// This iterator is constructed from `ops.once`.
pub fn Once(comptime T: type) type {
    return prim.MakeOnce(derive.DeriveIterator, T);
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
/// This iterator is constructed from `ops.repeat`.
pub fn Repeat(comptime T: type) type {
    return prim.MakeRepeat(derive.DeriveIterator, T);
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
