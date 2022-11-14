//! Iterator to Container converters.
//!
const std = @import("std");
const Con = @import("basis_concept");

const meta = @import("./meta.zig");
const range = @import("./range.zig");

const testing = std.testing;
const assert = std.debug.assert;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const BoundedArray = std.BoundedArray;
const SinglyLinkedList = std.SinglyLinkedList;

/// Create a slice consisting of the elements enumrated from `iter`.
pub fn slice_from_iter(alloc: Allocator, iter: anytype) Allocator.Error![]@TypeOf(iter).Item {
    const Iter = @TypeOf(iter);
    comptime assert(meta.isIterator(Iter));
    return (try array_list_from_iter(alloc, iter)).items;
}

test "slice_from_iter" {
    var rng = range.range(@as(u32, 0), 10);
    const slice = try slice_from_iter(testing.allocator, rng);
    defer testing.allocator.free(slice);
    try testing.expectEqual(@as(usize, 10), slice.len);
}

/// Create an ArrayList consisting of the elements enumrated from `iter`.
pub fn array_list_from_iter(alloc: Allocator, iter: anytype) Allocator.Error!ArrayList(@TypeOf(iter).Item) {
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
    var rng = range.range(@as(u32, 0), 10);
    const arr = try array_list_from_iter(testing.allocator, rng);
    defer arr.deinit();

    try testing.expectEqual(@as(usize, 10), arr.items.len);
    for (arr.items) |val, i| {
        try testing.expectEqual(i, val);
    }
}

/// Create an BoundedArray consisting of the elements enumrated from `iter`.
pub fn bounded_array_from_iter(comptime N: usize, iter: anytype) error{Overflow}!BoundedArray(@TypeOf(iter).Item, N) {
    const Iter = @TypeOf(iter);
    comptime assert(meta.isIterator(Iter));

    var xs = try BoundedArray(Iter.Item, N).init(0);
    var it = iter;
    while (it.next()) |val|
        try xs.append(val);
    return xs;
}

test "bounded_array_from_iter" {
    var rng = range.range(@as(u32, 0), 10);
    const arr = try bounded_array_from_iter(10, rng);

    try testing.expectEqual(@as(usize, 10), arr.constSlice().len);
    for (arr.constSlice()) |val, i| {
        try testing.expectEqual(i, val);
    }
}

pub fn singly_linked_list_from_iter(alloc: Allocator, iter: anytype) Allocator.Error!SinglyLinkedList(@TypeOf(iter).Item) {
    const Iter: type = @TypeOf(iter);
    comptime assert(meta.isIterator(Iter));
    comptime assert(Con.isCopyable(Iter.Item));
    const T: type = Iter.Item;

    const L = SinglyLinkedList(T);
    var list = L{};

    var it = iter;
    while (it.next()) |data| {
        var node = try alloc.create(L.Node);
        node.* = L.Node{ .data = data };
        list.prepend(node);
    }
    return list;
}

test "singly_linked_list_from_iter" {
    const allocator = testing.allocator;
    const rng = comptime range.range(@as(u32, 0), 10);
    // expand rng to an array
    const rs = comptime rs: {
        var rs: [rng.len()]u32 = undefined;
        var iter = rng;
        var i: usize = 0;
        while (iter.next()) |item| : (i += 1)
            rs[i] = item;
        break :rs rs;
    };

    var xs = try singly_linked_list_from_iter(allocator, rng);
    defer while (xs.popFirst()) |node| allocator.destroy(node);
    var it = xs.first;
    var i: usize = 0;
    while (it) |node| : ({
        it = node.next;
        i += 1;
    }) {
        try testing.expectEqual(rs[rs.len - i - 1], node.data);
    }
}
