//! Container to iterator converters.
//!
const std = @import("std");

const meta = @import("../meta.zig");

const ArrayList = std.ArrayList;
const SinglyLinkedList = std.SinglyLinkedList;
const BoundedArray = std.BoundedArray;
const TailQueue = std.TailQueue;

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
    return struct {
        pub const Self: type = @This();
        /// Const pointer points to items of an array.
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        array: *[N]T,
        index: usize,

        /// Creates an iterator wraps the `array`.
        pub fn new(array: *[N]T) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Item {
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

pub fn MakeArrayConstIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    return struct {
        pub const Self: type = @This();
        /// Const pointer points to items of an array.
        pub const Item: type = *const T;
        pub usingnamespace F(@This());

        array: *const [N]T,
        index: usize,

        pub fn new(array: *const [N]T) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Item {
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

        pub fn next(self: *Self) ?Item {
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

pub fn MakeSliceConstIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const T;
        pub usingnamespace F(@This());

        slice: []const T,
        index: usize,

        pub fn new(slice: []const T) Self {
            return Self{ .slice = slice, .index = 0 };
        }

        pub fn next(self: *Self) ?Item {
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

        pub fn next(self: *Self) ?Item {
            if (self.array.items.len <= self.index) {
                return null;
            }
            const index = self.index;
            self.index += 1;
            return &self.array.items[index];
        }
    };
}

pub fn MakeArrayListConstIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const T;
        pub usingnamespace F(@This());

        array: ArrayList(T),
        index: usize,

        pub fn new(array: ArrayList(T)) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Item {
            if (self.array.items.len <= self.index) {
                return null;
            }
            const index = self.index;
            self.index += 1;
            return &self.array.items[index];
        }
    };
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

        pub fn next(self: *Self) ?Item {
            if (self.node) |node| {
                self.node = node.next;
                return &node.data;
            }
            return null;
        }
    };
}

pub fn MakeSinglyLinkedListConstIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const T;
        pub usingnamespace F(@This());

        list: SinglyLinkedList(T),
        node: ?*const SinglyLinkedList(T).Node,

        pub fn new(list: SinglyLinkedList(T)) Self {
            return .{ .list = list, .node = list.first };
        }

        pub fn next(self: *Self) ?Item {
            if (self.node) |node| {
                self.node = node.next;
                return &node.data;
            }
            return null;
        }
    };
}

pub fn MakeBoundedArrayIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        array: *BoundedArray(T, N),
        index: usize,

        pub fn new(array: *BoundedArray(T, N)) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Item {
            if (self.index < self.array.slice().len) {
                const i = self.index;
                self.index += 1;
                return &self.array.slice()[i];
            } else {
                return null;
            }
        }
    };
}

pub fn MakeBoundedArrayConstIter(comptime F: fn (type) type, comptime T: type, comptime N: usize) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const T;
        pub usingnamespace F(@This());

        array: *BoundedArray(T, N),
        index: usize,

        pub fn new(array: *BoundedArray(T, N)) Self {
            return .{ .array = array, .index = 0 };
        }

        pub fn next(self: *Self) ?Item {
            if (self.index < self.array.slice().len) {
                const i = self.index;
                self.index += 1;
                return &self.array.slice()[i];
            } else {
                return null;
            }
        }
    };
}

pub fn MakeTailQueueIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *T;
        pub usingnamespace F(@This());

        queue: *TailQueue(T),

        pub fn new(queue: *TailQueue(T)) Self {
            return .{ .queue = queue };
        }

        pub fn next(self: *Self) ?Item {
            return if (self.queue.popFirst()) |node| &node.data else null;
        }
    };
}

pub fn MakeTailQueueConstIter(comptime F: fn (type) type, comptime T: type) type {
    return struct {
        pub const Self: type = @This();
        pub const Item: type = *const T;
        pub usingnamespace F(@This());

        queue: *TailQueue(T),

        pub fn new(queue: *TailQueue(T)) Self {
            return .{ .queue = queue };
        }

        pub fn next(self: *Self) ?Item {
            return if (self.queue.popFirst()) |node| &node.data else null;
        }
    };
}
