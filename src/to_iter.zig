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

pub fn MakeArrayIter(comptime F: fn (type) type, comptime Item: type, comptime N: usize) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Item;
        pub usingnamespace F(@This());

        array: [N]Item,
        index: u32,

        pub fn new(array: [N]Item) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.index < self.array.len) {
                const i = self.index;
                self.index += 1;
                return self.array[i];
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
    assert(ArrayIter(u32, arr.len).Item == u32);
    assert(meta.isIterator(ArrayIter(u32, arr.len)));
}

test "ArrayIter" {
    const arr = [_]u32{ 1, 2, 3 };
    var iter = ArrayIter(u32, arr.len).new(arr);
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 3);
    try testing.expect(iter.next() == null);
}

pub fn MakeSliceIter(comptime F: fn (type) type, comptime Item: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Item;
        pub usingnamespace F(@This());

        slice: []Item,
        index: u32,

        pub fn new(slice: []Item) Self {
            return Self{ .slice = slice, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.index < self.slice.len) {
                const i = self.index;
                self.index += 1;
                return self.slice[i];
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
    assert(SliceIter(u32).Item == u32);
    assert(meta.isIterator(SliceIter(u32)));
}

test "SliceIter" {
    var arr = [_]u32{ 1, 2, 3 };
    var iter = SliceIter(u32).new(arr[0..]);
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 3);
    try testing.expect(iter.next() == null);
}

pub fn MakeArrayListIter(comptime F: fn (type) type, comptime Item: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Item;
        pub usingnamespace F(@This());

        array: ArrayList(Item),
        index: usize,

        pub fn new(array: ArrayList(Item)) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.array.items.len <= self.index) {
                return null;
            }
            const index = self.index;
            self.index += 1;
            return self.array.items[index];
        }
    };
}

pub fn ArrayListIter(comptime Item: type) type {
    return MakeArrayListIter(Derive, Item);
}

comptime {
    assert(ArrayListIter(u32).Self == ArrayListIter(u32));
    assert(ArrayListIter(u32).Item == u32);
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
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 3);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 5);
    try testing.expect(iter.next() == null);
}

pub fn MakeSinglyLinkedListIter(comptime F: fn (type) type, comptime Item: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = Item;
        pub usingnamespace F(@This());

        list: SinglyLinkedList(Self.Item),
        node: ?*SinglyLinkedList(Self.Item).Node,

        pub fn new(list: SinglyLinkedList(Self.Item)) Self {
            return .{ .list = list, .node = list.first };
        }

        pub fn next(self: *Self) ?Self.Item {
            if (self.node) |node| {
                self.node = node.next;
                return node.data;
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
    assert(SinglyLinkedListIter(u32).Item == u32);
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

    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 3);
    try testing.expect(iter.next() == null);
}
