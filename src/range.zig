///! Range Iterator
///! 
const std = @import("std");

const meta = @import("./type.zig");
const derive = @import("./derive.zig");

const assert = std.debug.assert;
const testing = std.testing;

pub fn MakeRangeIter(comptime F: fn (type) type, comptime T: type) type {
    comptime assert(std.meta.trait.isNumber(T));

    return struct {
        pub const Self: type = @This();
        pub const Item: type = T;
        pub usingnamespace F(@This());

        curr: T,
        upper: T,
        step: T,

        pub fn new(curr: T, upper: T, step: T) Self {
            return .{ .curr = curr, .upper = upper, .step = step };
        }

        pub fn next(self: *Self) ?Item {
            if (self.curr < self.upper) {
                const curr = self.curr;
                self.curr += self.step;
                return curr;
            } else {
                return null;
            }
        }
    };
}

pub fn RangeIter(comptime Item: type) type {
    return MakeRangeIter(derive.Derive, Item);
}

comptime {
    assert(meta.isIterator(RangeIter(u32)));
    assert(meta.isIterator(RangeIter(i64)));
}

pub fn range(start: anytype, upper: @TypeOf(start), step: ?@TypeOf(start)) RangeIter(@TypeOf(start)) {
    if (step != null) {
        return RangeIter(@TypeOf(start)).new(start, upper, step.?);
    } else {
        return RangeIter(@TypeOf(start)).new(start, upper, @as(@TypeOf(start), 1));
    }
}

test "Range" {
    comptime {
        assert(meta.isIterator(@TypeOf(range(@as(u32, 0), 10, 1))));
        assert(meta.isIterator(@TypeOf(range(@as(u32, 0), 10, null))));
        assert(meta.isIterator(@TypeOf(range(@as(u32, 0), 10, 2))));
    }
    var iter = range(@as(u32, 0), 11, 2);
    try testing.expectEqual(@as(u32, 0), iter.next().?);
    try testing.expectEqual(@as(u32, 2), iter.next().?);
    try testing.expectEqual(@as(u32, 4), iter.next().?);
    try testing.expectEqual(@as(u32, 6), iter.next().?);
    try testing.expectEqual(@as(u32, 8), iter.next().?);
    try testing.expectEqual(@as(u32, 10), iter.next().?);
    try testing.expectEqual(@as(?u32, null), iter.next());
}

test "Range Iterator" {
    comptime {
        assert(meta.isIterator(@TypeOf(range(@as(u32, 0), 10, 1))));
    }
    var iter = range(@as(u32, 0), 11, 2)
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
    try testing.expectEqual(@as(u32, 3), iter.next().?);
    try testing.expectEqual(@as(u32, 5), iter.next().?);
    try testing.expectEqual(@as(u32, 7), iter.next().?);
    try testing.expectEqual(@as(?u32, null), iter.next());
}
