const std = @import("std");

const meta = @import("./meta.zig");
const iter = @import("./iter.zig");
const derive = @import("./derive.zig");

const assert = std.debug.assert;
const testing = std.testing;

/// An iterator that yields nothing
pub fn empty(comptime T: type) iter.Empty(T) {
    return iter.Empty(T).new();
}

test "empty" {
    const unit = struct {};
    const F = struct {
        fn id(x: f64) f64 {
            return x;
        }
        fn truth(x: void) bool {
            _ = x;
            return true;
        }
    };
    var empty_u32 = empty(u32);
    try testing.expectEqual(@as(?u32, null), empty_u32.next());
    var empty_f64 = empty(f64).map(F.id);
    try testing.expectEqual(@as(?f64, null), empty_f64.next());
    if (comptime meta.older_zig091) {
        var empty_void = empty(void).filter(F.truth);
        try testing.expectEqual(@as(?void, null), empty_void.next());
    }
    var empty_unit = empty(unit).cycle().take(5);
    try testing.expectEqual(@as(?unit, null), empty_unit.next());
}

/// Make an `Once` iterator.
/// Which yields the `value` exactly once.
pub fn once(value: anytype) iter.Once(@TypeOf(value)) {
    return iter.Once(@TypeOf(value)).new(value);
}

test "once" {
    const Unit = struct {};
    const F = struct {
        fn id(x: void) void {
            _ = x;
            return void{};
        }
        fn truth(x: void) bool {
            _ = x;
            return true;
        }
    };
    {
        var it = once(@as(u32, 42));
        try testing.expectEqual(@as(?u32, 42), it.next());
        try testing.expectEqual(@as(?u32, null), it.next());
    }
    if (comptime meta.older_zig091) {
        var it = once(void{}).map(F.id).filter(F.truth);
        try testing.expectEqual(@as(?void, void{}), it.next());
        try testing.expectEqual(@as(?void, null), it.next());
    }
    {
        var it = once(Unit{}).cycle().take(3);
        try testing.expectEqual(@as(?Unit, Unit{}), it.next());
        try testing.expectEqual(@as(?Unit, Unit{}), it.next());
        try testing.expectEqual(@as(?Unit, Unit{}), it.next());
        try testing.expectEqual(@as(?Unit, null), it.next());
    }
}

/// Takes iterators and zips them
pub fn zip(aiter: anytype, biter: anytype) derive.Zip(@TypeOf(aiter), @TypeOf(biter)) {
    comptime assert(meta.isIterator(@TypeOf(aiter)));
    comptime assert(meta.isIterator(@TypeOf(biter)));
    return derive.Zip(@TypeOf(aiter), @TypeOf(biter)).new(aiter, biter);
}

test "zip" {
    const tuple = @import("./tuple.zig");

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

    const Tup2 = tuple.Tuple2;
    const tup2 = tuple.tuple2;
    const from_slice = struct {
        fn call(xs: []u32) derive.Copied(to_iter.SliceIter(u32)) {
            return to_iter.SliceIter(u32).new(xs).copied();
        }
    }.call;

    {
        var xs = [_]u32{ 1, 2, 3 };
        var ys = [_]u32{ 4, 5, 6 };

        var it = zip(from_slice(xs[0..]), from_slice(ys[0..]));

        try testing.expectEqual(tup2(@as(u32, 1), @as(u32, 4)), it.next().?);
        try testing.expectEqual(tup2(@as(u32, 2), @as(u32, 5)), it.next().?);
        try testing.expectEqual(tup2(@as(u32, 3), @as(u32, 6)), it.next().?);
        try testing.expectEqual(@as(?Tup2(u32, u32), null), it.next());
    }

    {
        var xs = [_]u32{ 1, 2, 3 };
        var ys = [_]u32{ 4, 5, 6 };
        // Nested zips are also possible:
        var zs = [_]u32{ 7, 8, 9 };

        var it = zip(zip(from_slice(xs[0..]), from_slice(ys[0..])), from_slice(zs[0..]));

        try testing.expectEqual(tup2(tup2(@as(u32, 1), @as(u32, 4)), @as(u32, 7)), it.next().?);
        try testing.expectEqual(tup2(tup2(@as(u32, 2), @as(u32, 5)), @as(u32, 8)), it.next().?);
        try testing.expectEqual(tup2(tup2(@as(u32, 3), @as(u32, 6)), @as(u32, 9)), it.next().?);
        try testing.expectEqual(@as(?Tup2(Tup2(u32, u32), u32), null), it.next());
    }
}

/// Make an iterator yields given value repeatedly
pub fn repeat(value: anytype) iter.Repeat(@TypeOf(value)) {
    return iter.Repeat(@TypeOf(value)).new(value);
}

test "repeat" {
    {
        var it = repeat(@as(u32, 314));
        try testing.expectEqual(@as(u32, 314), try it.next().?);
        try testing.expectEqual(@as(u32, 314), try it.next().?);
        try testing.expectEqual(@as(u32, 314), try it.next().?);
        // repeat() never returns null
        // try testing.expectEqual(@as(?u32, null), it.next());
    }
    {
        const U = union(enum) { Tag1, Tag2 };
        const t1: U = U.Tag1;
        var it = repeat(t1).map(struct {
            fn f(x: meta.basis.Clone.ResultType(U)) U {
                if (x) |_| {} else |_| {}
                return U.Tag2;
            }
        }.f);
        try testing.expectEqual(U.Tag2, it.next().?);
        try testing.expectEqual(U.Tag2, it.next().?);
        try testing.expectEqual(U.Tag2, it.next().?);
        // repeat() never returns null
        // try testing.expectEqual(@as(?U, null), it.next());
    }
    {
        var xs = [_]u32{ 4, 5, 6 };

        var it = repeat(xs).take(3);

        try testing.expectEqual(xs, try it.next().?);
        try testing.expectEqual(xs, try it.next().?);
        try testing.expectEqual(xs, try it.next().?);
        try testing.expect(struct {
            fn is_null(x: anytype) bool {
                return x == null;
            }
        }.is_null(it.next()));
    }
}
