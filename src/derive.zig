const std = @import("std");
const meta = @import("./type.zig");
const iter = @import("./iter.zig");
const to_iter = @import("./to_iter.zig");

const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

const MakeSliceIter = to_iter.MakeSliceIter;
const isIterator = meta.isIterator;

fn DeriveMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    // already have "map" function
    if (meta.have_fun(Iter, "map")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn map(self: Iter, f: anytype) iter.IterMap(Iter, @TypeOf(f)) {
                return iter.IterMap(Iter, @TypeOf(f)).new(f, self);
            }
        };
    }
}

fn DeriveFilter(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    // already have "filter" function
    if (meta.have_fun(Iter, "filter")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn filter(self: Iter, p: fn (Iter.Item) bool) iter.IterFilter(Iter, fn (Iter.Item) bool) {
                return iter.IterFilter(Iter, fn (Iter.Item) bool).new(p, self);
            }
        };
    }
}

pub fn Derive(comptime Iter: type) type {
    return struct {
        pub usingnamespace DeriveMap(Iter);
        pub usingnamespace DeriveFilter(Iter);
    };
}

test "derive map" {
    const Double = struct {
        pub fn apply(x: u32) u32 {
            return x * 2;
        }
    };

    var arr = [_]u32{ 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveMap, u32);
    var map = Iter.new(arr[0..]).map(Double.apply);
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(map)));
    }
    try testing.expect(map.next().? == 2);
    try testing.expect(map.next().? == 4);
    try testing.expect(map.next().? == 6);
    try testing.expect(map.next() == null);
}

test "derive filter" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const IsEven = struct {
        pub fn apply(x: u32) bool {
            return x % 2 == 0;
        }
    };
    const Iter = MakeSliceIter(DeriveFilter, u32);
    var filter = Iter.new(arr[0..]).filter(IsEven.apply);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(filter)));
    }
    try testing.expect(filter.next().? == 2);
    try testing.expect(filter.next().? == 4);
    try testing.expect(filter.next().? == 6);
    try testing.expect(filter.next() == null);
}

test "derive" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const Triple = struct {
        pub fn apply(x: u32) u32 {
            return x * 3;
        }
    };
    const IsEven = struct {
        pub fn apply(x: u32) bool {
            return x % 2 == 0;
        }
    };
    const Iter = MakeSliceIter(Derive, u32);

    var mfm = Iter.new(arr[0..6])
        .map(Triple.apply) // derive map for SliceIter
        .filter(IsEven.apply) // more derive filter for IterMap
        .map(Triple.apply); // more more derive map for IterFilter
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(mfm)));
    }
    try testing.expect(mfm.next().? == 6 * 3);
    try testing.expect(mfm.next().? == 12 * 3);
    try testing.expect(mfm.next().? == 18 * 3);
    try testing.expect(mfm.next() == null);
}
