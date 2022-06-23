const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const SinglyLinkedList = std.SinglyLinkedList;
const testing = std.testing;
const assert = std.debug.assert;

pub fn ArrayIter(comptime Item: type, comptime N: usize) type {
    return struct {
        const Self: type = @This();
        const Item: type = Item;

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

comptime {
    const arr = [_]u32{ 1, 2, 3 };
    assert(ArrayIter(u32, arr.len).Self == ArrayIter(u32, arr.len));
    assert(ArrayIter(u32, arr.len).Item == u32);
}

test "ArrayIter" {
    const arr = [_]u32{ 1, 2, 3 };
    var iter = ArrayIter(u32, arr.len).new(arr);
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 3);
    try testing.expect(iter.next() == null);
}

pub fn SliceIter(comptime Item: type) type {
    return struct {
        const Self: type = @This();
        const Item: type = Item;

        slice: []const Item,
        index: u32,

        pub fn new(slice: []const Item) Self {
            return .{ .slice = slice, .index = 0 };
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

comptime {
    assert(SliceIter(u32).Self == SliceIter(u32));
    assert(SliceIter(u32).Item == u32);
}

test "SliceIter" {
    const arr = [_]u32{ 1, 2, 3 };
    var iter = SliceIter(u32).new(arr[0..]);
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 3);
    try testing.expect(iter.next() == null);
}

pub fn ArrayListIter(comptime Item: type) type {
    return struct {
        const Self: type = @This();
        const Item: type = Item;

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

pub fn SinglyLinkedListIter(comptime Item: type) type {
    return struct {
        const Self: type = @This();
        const Item: type = Item;

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

comptime {
    assert(SinglyLinkedListIter(u32).Self == SinglyLinkedListIter(u32));
    assert(SinglyLinkedListIter(u32).Item == u32);
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

fn is_func_type(comptime F: type) bool {
    const TypeInfo: type = std.builtin.TypeInfo;
    const FInfo: TypeInfo = @typeInfo(F);
    return switch (FInfo) {
        .Fn => |_| true,
        else => false,
    };
}

fn is_unary_func_type(comptime F: type) bool {
    const TypeInfo: type = std.builtin.TypeInfo;
    const FInfo: TypeInfo = @typeInfo(F);
    return switch (FInfo) {
        .Fn => |f| f.args.len == 1,
        else => false,
    };
}

fn domain(comptime F: type) type {
    comptime {
        assert(is_unary_func_type(F));
    }
    const FInfo: std.builtin.TypeInfo = @typeInfo(F);
    return FInfo.Fn.args[0].arg_type.?;
}

fn codomain(comptime F: type) type {
    comptime {
        assert(is_func_type(F));
    }
    const FInfo: std.builtin.TypeInfo = @typeInfo(F);
    if (FInfo.Fn.return_type) |ty| {
        return ty;
    } else {
        return void;
    }
}

comptime {
    assert(domain(fn (u32) u16) == u32);
    assert(codomain(fn (u32) u16) == u16);
    assert(domain(fn (u32) []const u8) == u32);
    assert(codomain(fn (u32) []const u8) == []const u8);
}

pub fn IterMap(comptime Iter: type, comptime F: type) type {
    return struct {
        const Self: type = @This();
        const Item: type = codomain(F);

        f: F,
        iter: Iter,

        pub fn new(f: F, iter: Iter) Self {
            return .{ .f = f, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            if (self.iter.next()) |item| {
                return self.f(item);
            } else {
                return null;
            }
        }
    };
}

comptime {
    assert(IterMap(SliceIter(u32), fn (u32) []u8).Self == IterMap(SliceIter(u32), fn (u32) []u8));
    assert(IterMap(SliceIter(u32), fn (u32) []u8).Item == []u8);
}

fn square(v: u32) u64 {
    return v * v;
}

test "IterMap" {
    const arr = [_]u32{ 1, 2, 3 };
    var arr_iter = ArrayIter(u32, arr.len).new(arr);
    var iter = IterMap(ArrayIter(u32, arr.len), fn (u32) u64).new(square, arr_iter);
    try testing.expect(iter.next().? == 1);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 9);
    try testing.expect(iter.next() == null);
}

pub fn IterFilter(comptime Iter: type) type {
    return struct {
        const Self: type = @This();
        const Item: type = Iter.Item;

        pred: fn (Self.Item) bool,
        iter: Iter,

        pub fn new(pred: fn (Self.Item) bool, iter: Iter) Self {
            return .{ .pred = pred, .iter = iter };
        }

        pub fn next(self: *Self) ?Item {
            while (self.iter.next()) |item| {
                if (self.pred(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}

fn is_even(value: u32) bool {
    return value % 2 == 0;
}

test "IterFilter" {
    const arr = [_]u32{ 1, 2, 3, 4, 5 } ** 3;
    var arr_iter = ArrayIter(u32, arr.len).new(arr);
    var iter = IterFilter(ArrayIter(u32, arr.len)).new(is_even, arr_iter);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next().? == 2);
    try testing.expect(iter.next().? == 4);
    try testing.expect(iter.next() == null);
}
