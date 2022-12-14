/// An example program use iter-zig package.
const std = @import("std");
const iter = @import("iter-zig");

const assert = std.debug.assert;
const print = std.debug.print;

const prelude = iter.prelude;

/// User defined iterator type
/// In order to follow the iterator conventions, takes a 'Derive'r.
pub fn MakeCounter(comptime Derive: fn (type) type) type {
    return struct {
        pub const Self = @This();
        pub const Item = u32;
        pub usingnamespace Derive(@This());

        count: u32,
        pub fn new() Self {
            return .{ .count = 0 };
        }
        pub fn next(self: *Self) ?Item {
            self.count += 1;
            if (self.count < 6)
                return self.count;
            return null;
        }
    };
}

pub fn Counter() type {
    return MakeCounter(prelude.DeriveIterator);
}

comptime {
    assert(prelude.isIterator(Counter()));
}

fn incr(x: u32) u32 {
    return x + 1;
}

fn even(x: u32) bool {
    return x % 2 == 0;
}

fn sum(st: *u32, v: u32) ?u32 {
    st.* += v;
    return st.*;
}

pub fn main() anyerror!void {
    print("Use basic iterator (SliceIter).\n", .{});
    print("================================================================\n", .{});
    {
        var arr = [_]u32{ 1, 2, 3 };
        var it = iter.to_iter.SliceIter(u32).new(arr[0..]);
        while (it.next()) |item| {
            print("item: {}\n", .{item.*});
        }
    }
    print("Use basic operations on a basic iterator.\n", .{});
    print("================================================================\n", .{});
    {
        var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
        var it = iter.to_iter.SliceIter(u32).new(arr[0..]).copied().filter(struct {
            fn call(x: u32) bool {
                return x % 2 == 0;
            }
        }.call);
        while (it.next()) |item| {
            print("item: {}\n", .{item});
        }
    }
    print("Use user defined iterator (Counter).\n", .{});
    print("================================================================\n", .{});
    {
        var it = Counter().new().map(struct {
            fn call(x: u32) u32 {
                return x + x;
            }
        }.call).enumerate();
        while (it.next()) |item| {
            print("item: {}: {}\n", .{ item.get(1), item.get(0) });
        }
    }
    print("Use user defined iterator(2) (Counter).\n", .{});
    print("================================================================\n", .{});
    {
        var counter = Counter().new();
        var it = counter
            .map(incr) // 2,3,4,5,6
            .filter(even) // 2,4,6
            .scan(@as(u32, 0), sum); // 2,6,12
        while (it.next()) |item| {
            print("item: {}\n", .{item});
        }
    }
    print("Use user defined iterator(3) (FlatMap).\n", .{});
    print("================================================================\n", .{});
    {
        var counter = Counter().new();
        var it = counter.flat_map(struct {
            fn f(v: u32) iter.range.Range(u32) {
                return iter.range.range(v, v + 3);
            }
        }.f);
        while (it.next()) |item| {
            print("item: {}\n", .{item});
        }
    }
}
