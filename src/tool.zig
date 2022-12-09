const std = @import("std");

const concept = @import("./concept.zig");

/// Returns an empty type.
pub fn DeriveNothing(comptime Iter: type) type {
    comptime std.debug.assert(concept.isIterator(Iter));
    return struct {};
}
