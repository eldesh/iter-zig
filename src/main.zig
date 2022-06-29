///! Iterator library.
///!
///! 'Iterator' is a generic name for iterating a set of values.
///! In this library, 'Iterator' is a vlaue of a kind of types satisfies some constraints.
///! The constraints are:
///! - Have `Self` type
///! - Have `Item` type
///! - Have `next` method takes `*Self` and returns `?Item`.
///!
///! Where the `next` method returns a 'next' value of the container.
///! If the next value is not exists, 'null' must be returned.
///! The order of occurence of values are implementation defined.
///! But all values must occurence exactly once before 'null' is returned.
///!
pub usingnamespace @import("./to_iter.zig");
pub usingnamespace @import("./iter.zig");
pub usingnamespace @import("./type.zig");
pub usingnamespace @import("./derive.zig");
