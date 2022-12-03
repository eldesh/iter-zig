const std = @import("std");

const meta = @import("./meta.zig");
const prim = @import("./derive/prim.zig");
const tuple = @import("./tuple.zig");
const derive = @import("./derive.zig");

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
    var emp_u32 = Empty(u32).new();
    try testing.expectEqual(@as(?u32, null), emp_u32.next());
    var emp_f64 = Empty(f64).new();
    try testing.expectEqual(@as(?f64, null), emp_f64.next());
    var emp_void = Empty(void).new();
    try testing.expectEqual(@as(?void, null), emp_void.next());
    var emp_unit = Empty(unit).new();
    try testing.expectEqual(@as(?unit, null), emp_unit.next());
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
