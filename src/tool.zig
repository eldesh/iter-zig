const std = @import("std");

const meta = @import("./meta.zig");

/// Returns an empty type.
pub fn DeriveNothing(comptime Iter: type) type {
    comptime std.debug.assert(meta.isIterator(Iter));
    return struct {};
}
