const std = @import("std");

const meta = @import("./meta.zig");
const iter = @import("./iter.zig");

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
    try testing.expectEqual(@as(?u32, null), empty(u32).next());
    try testing.expectEqual(@as(?f64, null), empty(f64).map(F.id).next());
    try testing.expectEqual(@as(?void, null), empty(void).filter(F.truth).next());
    try testing.expectEqual(@as(?unit, null), empty(unit).cycle().take(5).next());
}

/// Make an `Once` iterator.
/// Which yields the `value` exactly once.
pub fn once(value: anytype) iter.Once(@TypeOf(value)) {
    return iter.Once(@TypeOf(value)).new(value);
}

test "once" {
    const unit = struct {};
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
    {
        var it = once(void{}).map(F.id).filter(F.truth);
        try testing.expectEqual(@as(?void, void{}), it.next());
        try testing.expectEqual(@as(?void, null), it.next());
    }
    {
        var it = once(unit{}).cycle().take(3);
        try testing.expectEqual(@as(?unit, unit{}), it.next());
        try testing.expectEqual(@as(?unit, unit{}), it.next());
        try testing.expectEqual(@as(?unit, unit{}), it.next());
        try testing.expectEqual(@as(?unit, null), it.next());
    }
}
