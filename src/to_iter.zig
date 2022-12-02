//! Container to iterator converters.
//!
const std = @import("std");

const derive = @import("./derive.zig");
const meta = @import("./meta.zig");
const make = @import("./to_iter/make.zig");

const testing = std.testing;
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const SinglyLinkedList = std.SinglyLinkedList;
const BoundedArray = std.BoundedArray;
const TailQueue = std.TailQueue;

const DeriveIterator = derive.DeriveIterator;

/// Iterator wraps an array (typed to '[N]T').
///
/// # Arguments
/// - `F` - This function takes a minimum implementation of an iterator on an array as `@This()` and derives a type that provides several methods that depend on that minimum implementation.
/// - `T` - type of elements of an array
/// - `N` - length of an array
///
/// # Details
/// Creates an iterator type enumerates references pointing to elements of an array (`[N]T`).
/// Each items is a pointer to an item of an array.
///
pub fn MakeArrayIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    comptime make.MakeArrayIter(F, T, N);
}

/// Create an array iterator with passing DeriveIterator to MakeArrayIter.
pub fn ArrayIter(comptime Item: type, comptime N: usize) type {
    return make.MakeArrayIter(DeriveIterator, Item, N);
}

comptime {
    const arr = [_]u32{ 1, 2, 3 };
    assert(ArrayIter(u32, arr.len).Self == ArrayIter(u32, arr.len));
    assert(ArrayIter(u32, arr.len).Item == *u32);
    assert(meta.isIterator(ArrayIter(u32, arr.len)));
}

test "ArrayIter" {
    var arr = [_]u32{ 1, 2, 3 };
    var iter = ArrayIter(u32, arr.len).new(&arr);
    try testing.expectEqual(&arr[0], iter.next().?);
    try testing.expectEqual(&arr[1], iter.next().?);
    try testing.expectEqual(&arr[2], iter.next().?);
    try testing.expectEqual(@as(?ArrayIter(u32, arr.len).Item, null), iter.next());
}

pub fn MakeArrayConstIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    comptime return make.MakeArrayConstIter(F, T, N);
}

pub fn ArrayConstIter(comptime Item: type, comptime N: usize) type {
    return make.MakeArrayConstIter(DeriveIterator, Item, N);
}

comptime {
    const arr = [_]u32{ 1, 2, 3 };
    assert(ArrayConstIter(u32, arr.len).Self == ArrayConstIter(u32, arr.len));
    assert(ArrayConstIter(u32, arr.len).Item == *const u32);
    assert(meta.isIterator(ArrayConstIter(u32, arr.len)));
}

test "ArrayConstIter" {
    const arr = [_]u32{ 1, 2, 3 };
    var iter = ArrayConstIter(u32, arr.len).new(&arr);
    try testing.expectEqual(&arr[0], iter.next().?);
    try testing.expectEqual(&arr[1], iter.next().?);
    try testing.expectEqual(&arr[2], iter.next().?);
    try testing.expectEqual(@as(?@TypeOf(iter).Item, null), iter.next());
}

pub fn MakeSliceIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeSliceIter(F, T);
}

pub fn SliceIter(comptime Item: type) type {
    return make.MakeSliceIter(DeriveIterator, Item);
}

comptime {
    assert(SliceIter(u32).Self == SliceIter(u32));
    assert(SliceIter(u32).Item == *u32);
    assert(meta.isIterator(SliceIter(u32)));
}

test "SliceIter" {
    var arr = [_]u32{ 1, 2, 3 };
    var iter = SliceIter(u32).new(arr[0..]);
    try testing.expectEqual(&arr[0], iter.next().?);
    try testing.expectEqual(&arr[1], iter.next().?);
    try testing.expectEqual(&arr[2], iter.next().?);
    try testing.expectEqual(@as(?SliceIter(u32).Item, null), iter.next());

    var iter2 = SliceIter(u32).new(arr[0..]);
    // mutate value via iterator
    iter2.next().?.* = 2;
    iter2.next().?.* = 3;
    iter2.next().?.* = 4;
    try testing.expectEqual([_]u32{ 2, 3, 4 }, arr);
}

pub fn MakeSliceConstIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeSliceConstIter(F, T);
}

pub fn SliceConstIter(comptime Item: type) type {
    return make.MakeSliceConstIter(DeriveIterator, Item);
}

comptime {
    assert(SliceConstIter(u32).Self == SliceConstIter(u32));
    assert(SliceConstIter(u32).Item == *const u32);
    assert(meta.isIterator(SliceConstIter(u32)));
}

test "SliceConstIter" {
    const arr = [_]u32{ 1, 2, 3 };
    var iter = SliceConstIter(u32).new(arr[0..]);
    try testing.expectEqual(&arr[0], iter.next().?);
    try testing.expectEqual(&arr[1], iter.next().?);
    try testing.expectEqual(&arr[2], iter.next().?);
    try testing.expectEqual(@as(?SliceConstIter(u32).Item, null), iter.next());

    var iter2 = SliceConstIter(u32).new(arr[0..]);
    // cannot mutate value via const iterator
    // iter2.next().?.* = 2;
    _ = iter2;
}

pub fn MakeArrayListIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeArrayListIter(F, T);
}

pub fn ArrayListIter(comptime Item: type) type {
    return make.MakeArrayListIter(DeriveIterator, Item);
}

comptime {
    assert(ArrayListIter(u32).Self == ArrayListIter(u32));
    assert(ArrayListIter(u32).Item == *u32);
    assert(meta.isIterator(ArrayListIter(u32)));
}

test "ArrayListIter" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    var xs = ArrayList(u32).init(testing.allocator);
    defer xs.deinit();
    try xs.appendSlice(arr[0..]);

    var iter = ArrayListIter(u32).new(xs);
    try testing.expectEqual(@as(u32, 1), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 3), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 5), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());
}

pub fn MakeArrayListConstIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeArrayListConstIter(F, T);
}

pub fn ArrayListConstIter(comptime Item: type) type {
    return make.MakeArrayListConstIter(DeriveIterator, Item);
}

comptime {
    assert(ArrayListConstIter(u32).Self == ArrayListConstIter(u32));
    assert(ArrayListConstIter(u32).Item == *const u32);
    assert(meta.isIterator(ArrayListConstIter(u32)));
}

test "ArrayListConstIter" {
    var xs = ArrayList(u32).init(testing.allocator);
    defer xs.deinit();
    try xs.append(@as(u32, 1));
    try xs.append(@as(u32, 2));
    try xs.append(@as(u32, 3));
    try xs.append(@as(u32, 4));
    try xs.append(@as(u32, 5));

    var iter = ArrayListConstIter(u32).new(xs);
    try testing.expectEqual(@as(u32, 1), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 3), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 5), iter.next().?.*);
    try testing.expectEqual(@as(?*const u32, null), iter.next());
}

pub fn MakeSinglyLinkedListIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeSinglyLinkedListIter(F, T);
}

pub fn SinglyLinkedListIter(comptime Item: type) type {
    return make.MakeSinglyLinkedListIter(DeriveIterator, Item);
}

comptime {
    assert(SinglyLinkedListIter(u32).Self == SinglyLinkedListIter(u32));
    assert(SinglyLinkedListIter(u32).Item == *u32);
    assert(meta.isIterator(SinglyLinkedListIter(u32)));
}

test "SinglyLinkedListIter" {
    const L = SinglyLinkedList(u32);
    var list = L{};
    var one = L.Node{ .data = 1 };
    var two = L.Node{ .data = 2 };
    var three = L.Node{ .data = 3 };

    list.prepend(&three);
    list.prepend(&two);
    list.prepend(&one);

    var iter = SinglyLinkedListIter(u32).new(list);
    try testing.expectEqual(@as(u32, 1), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 3), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());

    var iter2 = SinglyLinkedListIter(u32).new(list);
    iter2.next().?.* *= 2;
    iter2.next().?.* *= 2;
    iter2.next().?.* *= 2;

    var iter3 = SinglyLinkedListIter(u32).new(list);
    try testing.expectEqual(@as(u32, 2), iter3.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter3.next().?.*);
    try testing.expectEqual(@as(u32, 6), iter3.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter3.next());
}

pub fn MakeSinglyLinkedListConstIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeSinglyLinkedListConstIter(F, T);
}

pub fn SinglyLinkedListConstIter(comptime Item: type) type {
    return make.MakeSinglyLinkedListConstIter(DeriveIterator, Item);
}

comptime {
    assert(SinglyLinkedListConstIter(u32).Self == SinglyLinkedListConstIter(u32));
    assert(SinglyLinkedListConstIter(u32).Item == *const u32);
    assert(meta.isIterator(SinglyLinkedListConstIter(u32)));
}

test "SinglyLinkedListConstIter" {
    const L = SinglyLinkedList(u32);
    var list = L{};
    var one = L.Node{ .data = 1 };
    var two = L.Node{ .data = 2 };
    var three = L.Node{ .data = 3 };

    list.prepend(&three);
    list.prepend(&two);
    list.prepend(&one);

    var iter = SinglyLinkedListConstIter(u32).new(list);
    // cannot mutate value via const iterator
    // iter.next().?.* *= 2;

    try testing.expectEqual(@as(u32, 1), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 3), iter.next().?.*);
    try testing.expectEqual(@as(?*const u32, null), iter.next());
}

pub fn MakeBoundedArrayIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    comptime return make.MakeBoundedArrayIter(F, T, N);
}

pub fn BoundedArrayIter(comptime T: type, comptime N: usize) type {
    return make.MakeBoundedArrayIter(DeriveIterator, T, N);
}

comptime {
    const arr = [3]u32{ 1, 2, 3 };
    assert(BoundedArrayIter(u32, arr.len).Self == BoundedArrayIter(u32, arr.len));
    assert(BoundedArrayIter(u32, arr.len).Item == *u32);
    assert(meta.isIterator(BoundedArrayIter(u32, arr.len)));
}

test "BoundedArrayIter" {
    var arr = BoundedArray(u32, 5).init(0) catch unreachable;
    try arr.appendSlice(&[_]u32{ 1, 2, 3 });
    var iter = BoundedArrayIter(u32, 5).new(&arr);
    try testing.expectEqual(&arr.constSlice()[0], iter.next().?);
    try testing.expectEqual(&arr.constSlice()[1], iter.next().?);
    try testing.expectEqual(&arr.constSlice()[2], iter.next().?);
    try testing.expectEqual(@as(?BoundedArrayIter(u32, 5).Item, null), iter.next());
}

pub fn MakeBoundedArrayConstIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    comptime return make.MakeBoundedArrayConstIter(F, T, N);
}

pub fn BoundedArrayConstIter(comptime T: type, comptime N: usize) type {
    return make.MakeBoundedArrayConstIter(DeriveIterator, T, N);
}

comptime {
    var arr = BoundedArray(u32, 5).init(3) catch unreachable;
    assert(BoundedArrayConstIter(u32, arr.capacity()).Self == BoundedArrayConstIter(u32, arr.capacity()));
    assert(BoundedArrayConstIter(u32, arr.capacity()).Item == *const u32);
    assert(meta.isIterator(BoundedArrayConstIter(u32, arr.len)));
}

test "BoundedArrayConstIter" {
    var arr = BoundedArray(u32, 5).init(0) catch unreachable;
    try arr.appendSlice(&[_]u32{ 1, 2, 3 });
    var iter = BoundedArrayConstIter(u32, 5).new(&arr);
    try testing.expectEqual(&arr.constSlice()[0], iter.next().?);
    try testing.expectEqual(&arr.constSlice()[1], iter.next().?);
    try testing.expectEqual(&arr.constSlice()[2], iter.next().?);
    try testing.expectEqual(@as(?BoundedArrayConstIter(u32, 5).Item, null), iter.next());
}

pub fn MakeTailQueueIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return MakeTailQueueIter(F, T);
}

pub fn TailQueueIter(comptime T: type) type {
    return make.MakeTailQueueIter(DeriveIterator, T);
}

comptime {
    assert(TailQueueIter(u32).Self == TailQueueIter(u32));
    assert(TailQueueIter(u32).Item == *u32);
    assert(meta.isIterator(TailQueueIter(u32)));
}

test "TailQueueIter" {
    const Q = TailQueue(u32);
    const node = struct {
        fn node(x: u32) Q.Node {
            return Q.Node{ .data = x };
        }
    }.node;
    var que = Q{};
    var nodes = [_]Q.Node{ node(1), node(2), node(3) };
    {
        for (nodes) |*n|
            que.append(n);

        var item: ?TailQueueIter(u32).Item = null;
        var iter = TailQueueIter(u32).new(&que);
        // update values of nodes via iter
        item = iter.next();
        item.?.* = item.?.* + 1;
        item = iter.next();
        item.?.* = item.?.* + 2;
        item = iter.next();
        item.?.* = item.?.* + 3;
    }
    {
        for (nodes) |*n|
            que.append(n);
        var iter = TailQueueIter(u32).new(&que);
        try testing.expectEqual(@as(u32, 2), iter.next().?.*);
        try testing.expectEqual(@as(u32, 4), iter.next().?.*);
        try testing.expectEqual(@as(u32, 6), iter.next().?.*);
        try testing.expectEqual(@as(?TailQueueIter(u32).Item, null), iter.next());
    }
}

pub fn MakeTailQueueConstIter(comptime F: fn (type) type, comptime T: type) type {
    comptime return make.MakeTailQueueConstIter(F, T);
}

pub fn TailQueueConstIter(comptime T: type) type {
    return make.MakeTailQueueConstIter(DeriveIterator, T);
}

comptime {
    assert(TailQueueConstIter(u32).Self == TailQueueConstIter(u32));
    assert(TailQueueConstIter(u32).Item == *const u32);
    assert(meta.isIterator(TailQueueConstIter(u32)));
}

test "TailQueueConstIter" {
    const Q = TailQueue(u32);
    const node = struct {
        fn node(x: u32) Q.Node {
            return Q.Node{ .data = x };
        }
    }.node;
    var que = Q{};
    var nodes = [_]Q.Node{ node(1), node(2), node(3) };
    for (nodes) |*n|
        que.append(n);

    var iter = TailQueueConstIter(u32).new(&que);
    try testing.expectEqual(@as(*const u32, &nodes[0].data), iter.next().?);
    try testing.expectEqual(@as(*const u32, &nodes[1].data), iter.next().?);
    try testing.expectEqual(@as(*const u32, &nodes[2].data), iter.next().?);
    try testing.expectEqual(@as(?TailQueueConstIter(u32).Item, null), iter.next());
}
