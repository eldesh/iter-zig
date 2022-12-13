//! Type Constructor of Range of numbers
//!
//! `Range` represents that a half open interval of numbers.
//! For integral types, `Range` would be an iterator.
//! The iterator incremented by 1 from `start`.
const std = @import("std");

const meta = @import("../meta.zig");

const assert = std.debug.assert;

/// Make a type of range on integers.
///
/// # Assert
/// - std.meta.trait.isIntegral(T)
fn MakeIntegerRange(comptime F: fn (type) type, comptime T: type) type {
    comptime {
        assert(std.meta.trait.isIntegral(T));
        return struct {
            pub const Self: type = @This();
            pub const Item: type = T;
            pub usingnamespace F(@This());

            start: T,
            end: T,

            pub fn new(start: T, end: T) Self {
                return .{ .start = start, .end = end };
            }

            /// Check that the `value` is contained in the range.
            pub fn contains(self: *const Self, value: T) bool {
                return self.start <= value and value < self.end;
            }

            /// Check that the range is empty.
            pub fn is_empty(self: *const Self) bool {
                return self.end <= self.start;
            }

            /// For integer types, this type would be an iterator.
            pub fn next(self: *Self) ?Item {
                if (self.start < self.end) {
                    const start = self.start;
                    self.start += 1;
                    return start;
                } else {
                    return null;
                }
            }

            /// A range specific implementation of `count`.
            /// The result is same as the `len` method.
            pub fn count(self: *Self) usize {
                return self.len();
            }

            /// Length of the sequence without consuming.
            pub fn len(self: *const Self) usize {
                return if (self.is_empty())
                    0
                else
                    @intCast(usize, self.end - self.start);
            }
        };
    }
}

/// Make a type of range on the floating point numbers.
///
/// # Assert
/// - std.meta.trait.isFloat(T)
fn MakeFloatRange(comptime T: type) type {
    comptime {
        assert(std.meta.trait.isFloat(T));
        return struct {
            pub const Self: type = @This();
            pub const Item: type = T;

            start: T,
            end: T,

            pub fn new(start: T, end: T) Self {
                return .{ .start = start, .end = end };
            }

            /// Check that the `value` is contained in the range.
            pub fn contains(self: *const Self, value: T) bool {
                return self.start <= value and value < self.end;
            }

            /// Check that the range is empty.
            pub fn is_empty(self: *const Self) bool {
                return self.end <= self.start;
            }
        };
    }
}

/// Make a type of range on numbers.
///
/// # Details
/// If `T` is an integer type, the result type is `Iterator`.
/// For integer types, it combines functions derived by `F` which takes primitive integer range type.
///
/// # Assert
/// - std.meta.trait.isIntegral(T) ==> isIterator(MakeRange(F, T))
pub fn MakeRange(comptime F: fn (type) type, comptime T: type) type {
    comptime {
        assert(std.meta.trait.isNumber(T));
        return if (std.meta.trait.isIntegral(T))
            MakeIntegerRange(F, T)
        else
            MakeFloatRange(T);
    }
}
