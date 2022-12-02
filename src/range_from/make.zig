//! RangeFrom Iterator
//! 
//! `RangeFrom` represents that an interval of numbers which right endpoint is infinite.
//! For integral types, `RangeFrom` would be an iterator.
//! The iterator incremented by 1 from `start`.
//! The behaviour when an overflow occurs is implementation dependent.
const std = @import("std");

const meta = @import("../meta.zig");

const assert = std.debug.assert;

fn MakeIntegerRangeFrom(comptime F: fn (type) type, comptime T: type) type {
    comptime {
        assert(std.meta.trait.isIntegral(T));
        return struct {
            pub const Self: type = @This();
            pub const Item: type = T;
            pub usingnamespace F(@This());

            start: T,

            pub fn new(start: T) Self {
                return .{ .start = start };
            }

            /// Check that the `value` is contained in the range.
            pub fn contains(self: *const Self, value: T) bool {
                return self.start <= value;
            }

            /// For integer types, this type would be an iterator.
            pub fn next(self: *Self) ?Item {
                const start = self.start;
                self.start += 1;
                return start;
            }
        };
    }
}

fn MakeFloatRangeFrom(comptime T: type) type {
    comptime {
        assert(std.meta.trait.isFloat(T));
        return struct {
            pub const Self: type = @This();
            pub const Item: type = T;

            start: T,

            pub fn new(start: T) Self {
                return .{ .start = start };
            }

            /// Check that the `value` is contained in the range.
            pub fn contains(self: *const Self, value: T) bool {
                return self.start <= value;
            }
        };
    }
}

pub fn MakeRangeFrom(comptime F: fn (type) type, comptime T: type) type {
    comptime {
        assert(std.meta.trait.isNumber(T));
        return if (std.meta.trait.isIntegral(T))
            MakeIntegerRangeFrom(F, T)
        else
            MakeFloatRangeFrom(T);
    }
}
