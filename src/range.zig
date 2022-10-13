//! Range Iterator
//!
const std = @import("std");

const meta = @import("./meta.zig");
const iter = @import("./iter.zig");
const derive = @import("./derive.zig");

const assert = std.debug.assert;
const testing = std.testing;

pub fn MakeRange(comptime F: fn (type) type, comptime T: type) type {
    comptime assert(std.meta.trait.isNumber(T));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace if (std.meta.trait.isIntegral(T))
            F(@This())
        else
            struct {};

        start: T,
        end: T,

        pub fn new(start: T, end: T) Self {
            return .{ .start = start, .end = end };
        }

        pub fn contains(self: Self, value: T) bool {
            return self.start <= value and value < self.end;
        }

        pub fn is_empty(self: Self) bool {
            return self.end <= self.start;
        }

        pub usingnamespace if (std.meta.trait.isIntegral(T))
            struct {
                pub fn next(self: *Self) ?Item {
                    if (self.start < self.end) {
                        const start = self.start;
                        self.start += 1;
                        return start;
                    } else {
                        return null;
                    }
                }

                pub fn count(self: *const Self) usize {
                    return if (self.is_empty())
                        0
                    else
                        @intCast(usize, self.end - self.start);
                }
            }
        else
            struct {};
    };
}

pub fn Range(comptime Item: type) type {
    return MakeRange(derive.DeriveIterator, Item);
}

comptime {
    assert(meta.isIterator(Range(u32)));
    assert(meta.isIterator(Range(i64)));
    assert(meta.isCopyable(Range(i64)));
    assert(meta.isClonable(Range(u64)));
    assert(!meta.isIterator(Range(f64)));
    assert(meta.isCopyable(Range(f64)));
    assert(meta.isClonable(Range(f64)));
}

pub fn range(start: anytype, end: @TypeOf(start)) Range(@TypeOf(start)) {
    return Range(@TypeOf(start)).new(start, end);
}

test "Range" {
    comptime {
        assert(meta.isIterator(@TypeOf(range(@as(u32, 0), 10))));
        assert(!meta.isIterator(@TypeOf(range(@as(f64, 0.0), 10.0))));
    }
    {
        try testing.expect(!Range(u32).new(10, 10).contains(3));
        try testing.expect(!Range(u32).new(10, 10).contains(9));
        try testing.expect(!Range(u32).new(10, 10).contains(10));
        try testing.expect(Range(u32).new(10, 10).is_empty());
    }
    {
        try testing.expect(Range(u32).new(3, 10).contains(3));
        try testing.expect(Range(u32).new(3, 10).contains(9));
        try testing.expect(!Range(u32).new(3, 10).contains(10));
        try testing.expect(!Range(u32).new(3, 10).is_empty());
    }
    {
        try testing.expect(Range(f32).new(3.0, 10.0).contains(3.0));
        try testing.expect(Range(f32).new(3.0, 10.0).contains(9.0));
        try testing.expect(Range(f32).new(3.0, 10.0).contains(9.9));
        try testing.expect(!Range(f32).new(3.0, 10.0).contains(10.0));
        try testing.expect(!Range(f32).new(3.0, 10.0).is_empty());
    }
    {
        var it = range(@as(u32, 0), 11).step_by(2);
        try testing.expectEqual(@as(u32, 0), it.next().?);
        try testing.expectEqual(@as(u32, 2), it.next().?);
        try testing.expectEqual(@as(u32, 4), it.next().?);
        try testing.expectEqual(@as(u32, 6), it.next().?);
        try testing.expectEqual(@as(u32, 8), it.next().?);
        try testing.expectEqual(@as(u32, 10), it.next().?);
        try testing.expectEqual(@as(?u32, null), it.next());
    }
}

test "Range Iterator" {
    comptime {
        assert(meta.isIterator(@TypeOf(range(@as(u32, 0), 10))));
    }
    var it = range(@as(u32, 0), 11).step_by(2)
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
    try testing.expectEqual(@as(?u32, null), it.next());
}
