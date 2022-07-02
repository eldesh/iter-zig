///! Iterator to Container converters.
///! 
const std = @import("std");
const meta = @import("./type.zig");
const range = @import("./range.zig");

const testing = std.testing;
const assert = std.debug.assert;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub fn slice_from_iter_with_allocator(alloc: Allocator, iter: anytype) Allocator.Error![]@TypeOf(iter).Item {
    return (try array_list_from_iter_with_allocator(alloc, iter)).items;
}

test "slice_from_iter" {
    var rng = range.range(@as(usize, 0), 10, 1);
    const slice = try slice_from_iter_with_allocator(testing.allocator, rng);
    defer testing.allocator.free(slice);
    try testing.expectEqual(@as(usize, 10), slice.len);
}

pub fn array_list_from_iter_with_allocator(alloc: Allocator, iter: anytype) Allocator.Error!ArrayList(@TypeOf(iter).Item) {
    const Iter = @TypeOf(iter);
    comptime assert(meta.isIterator(Iter));

    var xs = ArrayList(Iter.Item).init(alloc);
    var it = iter;
    while (it.next()) |val| {
        try xs.append(val);
    }
    return xs;
}

test "array_list_from_iter" {
    var rng = range.range(@as(usize, 0), 10, 1);
    const arr = try array_list_from_iter_with_allocator(testing.allocator, rng);
    defer arr.deinit();

    try testing.expectEqual(@as(usize, 10), arr.items.len);
    for (arr.items) |val, i| {
        try testing.expectEqual(i, val);
    }
}
