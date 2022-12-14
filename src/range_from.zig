//! RangeFrom Iterator
//! 
//! `RangeFrom` represents that an interval of numbers which right endpoint is infinite.
//! For integral types, `RangeFrom` would be an iterator.
//! The iterator incremented by 1 from `start`.
//! The behaviour when an overflow occurs is implementation dependent.
const std = @import("std");

const meta = @import("./meta.zig");
const derive = @import("./derive.zig");
const make = @import("./range_from/make.zig");
const concept = @import("./concept.zig");

const assert = std.debug.assert;
const testing = std.testing;

/// Returns an open range type on `T` derived with `F`.
pub fn MakeRangeFrom(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeRangeFrom(F, T);
}

/// Return type of sequence of numbers
///
/// # Details
/// Return type of sequence of numbers
/// For integer types, it is an iterator is incremented by 1.
pub fn RangeFrom(comptime Item: type) type {
    comptime return MakeRangeFrom(derive.DeriveIterator, Item);
}

comptime {
    assert(concept.isIterator(RangeFrom(u32)));
    assert(concept.isIterator(RangeFrom(i64)));
    assert(meta.basis.isCopyable(RangeFrom(i64)));
    assert(meta.basis.isClonable(RangeFrom(u64)));
    assert(!concept.isIterator(RangeFrom(f64)));
    assert(meta.basis.isCopyable(RangeFrom(f64)));
    assert(meta.basis.isClonable(RangeFrom(f64)));
}

/// Interval of numbers from `start`
///
/// # Details
/// Interval of numbers from `start`.
/// For integer types, it is an iterator is incremented by 1.
pub fn range_from(start: anytype) RangeFrom(@TypeOf(start)) {
    return RangeFrom(@TypeOf(start)).new(start);
}

test "RangeFrom" {
    comptime {
        assert(concept.isIterator(@TypeOf(range_from(@as(u32, 0)))));
        assert(!concept.isIterator(@TypeOf(range_from(@as(f64, 0.0)))));
    }
    {
        try testing.expect(!RangeFrom(u32).new(10).contains(3));
        try testing.expect(!RangeFrom(u32).new(10).contains(9));
        try testing.expect(RangeFrom(u32).new(10).contains(10));
    }
    {
        try testing.expect(RangeFrom(u32).new(3).contains(3));
        try testing.expect(RangeFrom(u32).new(3).contains(9));
        try testing.expect(RangeFrom(u32).new(3).contains(10));
    }
    {
        try testing.expect(RangeFrom(f32).new(3.0).contains(3.0));
        try testing.expect(RangeFrom(f32).new(3.0).contains(3.1));
        try testing.expect(RangeFrom(f32).new(3.0).contains(9.0));
        try testing.expect(RangeFrom(f32).new(3.0).contains(10.0));
        try testing.expect(RangeFrom(f32).new(3.0).contains(123.456));
    }
    {
        var it = range_from(@as(u32, 0)).step_by(2);
        try testing.expectEqual(@as(u32, 0), it.next().?);
        try testing.expectEqual(@as(u32, 2), it.next().?);
        try testing.expectEqual(@as(u32, 4), it.next().?);
        try testing.expectEqual(@as(u32, 6), it.next().?);
        try testing.expectEqual(@as(u32, 8), it.next().?);
        try testing.expectEqual(@as(u32, 10), it.next().?);
    }
}

test "RangeFrom Iterator" {
    comptime {
        assert(concept.isIterator(@TypeOf(range_from(@as(u32, 0)))));
    }
    var it = range_from(@as(u32, 0)).step_by(2)
        .filter(struct {
        fn lt5(x: u32) bool {
            return x < 5;
        }
    }.lt5)
        .map(struct {
        fn add3(x: u32) u32 {
            return x + 3;
        }
    }.add3);
    try testing.expectEqual(@as(u32, 3), it.next().?);
    try testing.expectEqual(@as(u32, 5), it.next().?);
    try testing.expectEqual(@as(u32, 7), it.next().?);
}
