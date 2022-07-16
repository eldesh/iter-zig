const std = @import("std");
const testing = std.testing;

const assert = std.debug.assert;

pub fn Tuple1(comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Arity: comptime_int = 1;
        pub const StdTuple: type = std.meta.Tuple(&[_]type{T});

        t: T,

        pub fn new(t: T) Self {
            return .{ .t = t };
        }

        pub fn getType(comptime N: comptime_int) type {
            if (N == 0)
                return T;
        }

        /// Project field indexed with `N`.
        /// The `N` must be `0` or `1`.
        pub fn get(self: *const Self, comptime N: comptime_int) Self.getType(N) {
            if (N == 0)
                return self.t;
        }

        /// Construct from std tuple.
        ///
        /// Construct a Tuple2 from an anonymous struct with just 2 fields such as `.{ foo, bar, ... }`.
        /// This may be typed to `std.meta.Tuple(..)`.
        pub fn fromStd(t: anytype) Self {
            comptime assert(std.meta.trait.isTuple(@TypeOf(t)));
            comptime assert(@typeInfo(@TypeOf(t)).Struct.fields.len == Arity);
            return Self.new(t.@"0");
        }

        pub fn intoStd(self: Self) StdTuple {
            return .{self.t};
        }
    };
}

pub fn Tuple2(comptime T: type, comptime U: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Arity: comptime_int = 2;
        pub const StdTuple: type = std.meta.Tuple(&[_]type{ T, U });

        t: T,
        u: U,

        pub fn new(t: T, u: U) Self {
            return .{ .t = t, .u = u };
        }

        pub fn getType(comptime N: comptime_int) type {
            if (N == 0)
                return T;
            if (N == 1)
                return U;
        }

        /// Project field indexed with `N`.
        /// The `N` must be `0` or `1`.
        pub fn get(self: *const Self, comptime N: comptime_int) Self.getType(N) {
            if (N == 0)
                return self.t;
            if (N == 1)
                return self.u;
        }

        /// Construct from std tuple.
        ///
        /// Construct a Tuple2 from an anonymous struct with just 2 fields such as `.{ foo, bar, ... }`.
        /// This may be typed to `std.meta.Tuple(..)`.
        pub fn fromStd(t: anytype) Self {
            comptime assert(std.meta.trait.isTuple(@TypeOf(t)));
            comptime assert(@typeInfo(@TypeOf(t)).Struct.fields.len == Arity);
            return Self.new(t.@"0", t.@"1");
        }

        pub fn intoStd(self: Self) StdTuple {
            return .{ self.t, self.u };
        }
    };
}

pub fn tuple2(v1: anytype, v2: anytype) Tuple2(@TypeOf(v1), @TypeOf(v2)) {
    return Tuple2(@TypeOf(v1), @TypeOf(v2)).new(v1, v2);
}

test "tuple2" {
    const foo: []const u8 = "foo";
    const tup = tuple2(foo, @as(usize, 42));
    try testing.expectEqual(tup, tuple2(tup.get(0), tup.get(1)));
}

test "to/from std.tuple" {
    const foo: []const u8 = "foo";
    const std_tuple: std.meta.Tuple(&[_]type{ []const u8, usize }) = .{ foo, 42 };
    const org_tuple2 = tuple2(foo, @as(usize, 42));

    comptime {
        assert(@TypeOf(org_tuple2).getType(0) == []const u8);
        assert(@TypeOf(org_tuple2).getType(1) == usize);
    }

    try testing.expectEqual(org_tuple2, @TypeOf(org_tuple2).fromStd(std_tuple));
    try testing.expectEqual(org_tuple2, @TypeOf(org_tuple2).fromStd(.{ foo, 42 }));
    try testing.expectEqual(org_tuple2, @TypeOf(org_tuple2).fromStd(org_tuple2.intoStd()));
}
