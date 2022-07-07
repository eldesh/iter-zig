///! Container to iterator converters.
///! 
const std = @import("std");
const derive = @import("./derive.zig");
const meta = @import("./type.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const SinglyLinkedList = std.SinglyLinkedList;
const testing = std.testing;
const assert = std.debug.assert;

const Derive = derive.Derive;

pub fn MakeArrayIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        array: *[N]T,
        index: usize,

        pub fn new(array: *[N]T) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.index < self.array.len) {
                const i = self.index;
                self.index += 1;
                return &self.array[i];
            } else {
                return null;
            }
        }
    };
}

pub fn ArrayIter(comptime Item: type, comptime N: usize) type {
    return MakeArrayIter(Derive, Item, N);
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

pub fn MakeSliceIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        slice: []T,
        index: usize,

        pub fn new(slice: []T) Self {
            return Self{ .slice = slice, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.index < self.slice.len) {
                const i = self.index;
                self.index += 1;
                return &self.slice[i];
            } else {
                return null;
            }
        }
    };
}

pub fn SliceIter(comptime Item: type) type {
    return MakeSliceIter(Derive, Item);
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

pub fn MakeArrayListIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        array: ArrayList(T),
        index: usize,

        pub fn new(array: ArrayList(T)) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.array.items.len <= self.index) {
                return null;
            }
            const index = self.index;
            self.index += 1;
            return &self.array.items[index];
        }
    };
}

pub fn ArrayListIter(comptime Item: type) type {
    return MakeArrayListIter(Derive, Item);
}

comptime {
    assert(ArrayListIter(u32).Self == ArrayListIter(u32));
    assert(ArrayListIter(u32).Item == *u32);
    assert(meta.isIterator(ArrayListIter(u32)));
}

test "ArrayListIter" {
    var xs = ArrayList(u32).init(testing.allocator);
    defer xs.deinit();
    try xs.append(@as(u32, 1));
    try xs.append(@as(u32, 2));
    try xs.append(@as(u32, 3));
    try xs.append(@as(u32, 4));
    try xs.append(@as(u32, 5));

    var iter = ArrayListIter(u32).new(xs);
    try testing.expectEqual(@as(u32, 1), iter.next().?.*);
    try testing.expectEqual(@as(u32, 2), iter.next().?.*);
    try testing.expectEqual(@as(u32, 3), iter.next().?.*);
    try testing.expectEqual(@as(u32, 4), iter.next().?.*);
    try testing.expectEqual(@as(u32, 5), iter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), iter.next());
}

pub fn MakeSinglyLinkedListIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        list: SinglyLinkedList(T),
        node: ?*SinglyLinkedList(T).Node,

        pub fn new(list: SinglyLinkedList(T)) Self {
            return .{ .list = list, .node = list.first };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.node) |node| {
                self.node = node.next;
                return &node.data;
            }
            return null;
        }
    };
}

pub fn SinglyLinkedListIter(comptime Item: type) type {
    return MakeSinglyLinkedListIter(Derive, Item);
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
}
