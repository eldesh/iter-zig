const std = @import("std");
const meta = std.meta;
const testing = std.testing;

const assert = std.debug.assert;

pub fn Tuple2(comptime T: type, comptime U: type) type {
    return struct {
        pub const Self: type = @This();

        t: T,
        u: U,

        pub fn new(t: T, u: U) Self {
            return .{ .t = t, .u = u };
        }

        pub fn get(self: *const Self, comptime N: comptime_int) ret: {
            if (N == 0)
                break :ret @TypeOf(self.t);
            if (N == 1)
                break :ret @TypeOf(self.u);
        } {
            if (N == 0)
                return self.t;
            if (N == 1)
                return self.u;
        }

        pub fn fromStdTuple(t: anytype) Self {
            comptime assert(std.meta.trait.isTuple(@TypeOf(t)));
            return Self.new(t.@"0", t.@"1");
        }
    };
}

pub fn tuple2(v1: anytype, v2: anytype) Tuple2(@TypeOf(v1), @TypeOf(v2)) {
    return Tuple2(@TypeOf(v1), @TypeOf(v2)).new(v1, v2);
}

test "from std.tuple" {
    const foo: []const u8 = "foo";
    const std_tuple: meta.Tuple(&[_]type{ []const u8, usize }) = .{ foo, 42 };
    const org_tuple2 = tuple2(foo, @as(usize, 42));
    try testing.expectEqual(org_tuple2, @TypeOf(org_tuple2).fromStdTuple(std_tuple));
}
