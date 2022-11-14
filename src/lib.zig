//! A basic Iterator library.
//!
//! 'Iterator' is a generic name for iterating a set of values.
//! In this library, 'Iterator' is a vlaue of a kind of types satisfies some constraints.
//! The constraints are:
//! - Have `Self` type
//! - Have `Item` type
//! - Have `next` method takes `*Self` and returns `?Item`.
//!
//! Where the `next` method returns a 'next' value of the container.
//! If the next value is not exists, 'null' must be returned.
//! The order of occurence of values are implementation defined.
//! But all values must occurence exactly once before 'null' is returned.
//!
pub const to_iter = @import("./to_iter.zig");
pub const iter = @import("./iter.zig");
pub const meta = @import("./meta.zig");
pub const derive = @import("./derive.zig");
pub const from_iter = @import("./from_iter.zig");
pub const range = @import("./range.zig");
pub const range_from = @import("./range_from.zig");
pub const tuple = @import("./tuple.zig");
pub const ops = @import("./ops.zig");
pub const concept = @import("./concept.zig");

pub const prelude = struct {
    pub const isIterator: fn (type) bool = meta.isIterator;
    pub const DeriveIterator: fn (type) type = derive.DeriveIterator;
};

test {
    @import("std").testing.refAllDecls(@This());
}
