//! RangeFrom Iterator
//! 
//! `RangeFrom` represents that an interval of numbers which right endpoint is infinite.
//! For integral types, `RangeFrom` would be an iterator.
//! The iterator incremented by 1 from `start`.
//! The behaviour when an overflow occurs is implementation dependent.
const std = @import("std");

const meta = @import("./meta.zig");
const iter = @import("./iter.zig");
const derive = @import("./derive.zig");

const assert = std.debug.assert;
const testing = std.testing;

pub fn MakeRangeFrom(comptime F: fn (type) type, comptime T: type) type {
    comptime assert(std.meta.trait.isNumber(T));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace if (std.meta.trait.isIntegral(T))
            F(@This())
        else
            struct {};

        start: T,

        pub fn new(start: T) Self {
            return .{ .start = start };
        }

        /// Check that the `value` is contained in the range.
        pub fn contains(self: *const Self, value: T) bool {
            return self.start <= value;
        }

        /// For integer types, this type would be an iterator.
        pub usingnamespace if (std.meta.trait.isIntegral(T))
            struct {
                pub fn next(self: *Self) ?Item {
                    const start = self.start;
                    self.start += 1;
                    return start;
                }
            }
        else
            struct {};
    };
}

/// Return type of sequence of numbers
///
/// # Details
/// Return type of sequence of numbers
/// For integer types, it is an iterator is incremented by 1.
pub fn RangeFrom(comptime Item: type) type {
    return MakeRangeFrom(derive.DeriveIterator, Item);
}

comptime {
    assert(meta.isIterator(RangeFrom(u32)));
    assert(meta.isIterator(RangeFrom(i64)));
    assert(meta.isCopyable(RangeFrom(i64)));
    assert(meta.isClonable(RangeFrom(u64)));
    assert(!meta.isIterator(RangeFrom(f64)));
    assert(meta.isCopyable(RangeFrom(f64)));
    assert(meta.isClonable(RangeFrom(f64)));
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
        assert(meta.isIterator(@TypeOf(range_from(@as(u32, 0)))));
        assert(!meta.isIterator(@TypeOf(range_from(@as(f64, 0.0)))));
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
        assert(meta.isIterator(@TypeOf(range_from(@as(u32, 0)))));
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
