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

test "derive map" {
    const Double = struct {
        fn apply(x: *const u32) u32 {
            return x.* * 2;
        }
    };

    var arr = [_]u32{ 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveMap, u32);
    var map = Iter.new(arr[0..]).map(Double.apply);
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(map)));
    }
    try testing.expectEqual(@as(?u32, 2), map.next());
    try testing.expectEqual(@as(?u32, 4), map.next());
    try testing.expectEqual(@as(?u32, 6), map.next());
    try testing.expectEqual(@as(?u32, null), map.next());
}

fn DeriveFilter(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

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

test "derive filter" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const IsEven = struct {
        fn apply(x: *const u32) bool {
            return x.* % 2 == 0;
        }
    };
    const Iter = MakeSliceIter(DeriveFilter, u32);
    var filter = Iter.new(arr[0..]).filter(IsEven.apply);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(filter)));
    }
    try testing.expectEqual(@as(u32, 2), filter.next().?.*);
    try testing.expectEqual(@as(u32, 4), filter.next().?.*);
    try testing.expectEqual(@as(u32, 6), filter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), filter.next());
}

fn DeriveFlatMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "flat_map")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn flat_map(self: Iter, m: anytype) iter.FlatMap(Iter, @TypeOf(m)) {
                return iter.FlatMap(Iter, @TypeOf(m)).new(m, self);
            }
        };
    }
}

test "derive flat_map" {
    var arr = [_][]const u8{ "1", "2", "foo", "3", "bar" };
    const ParseInt = struct {
        fn apply(x: *const []const u8) ?u32 {
            return std.fmt.parseInt(u32, x.*, 10) catch null;
        }
    };
    const Iter = MakeSliceIter(DeriveFlatMap, []const u8);
    var flat_map = Iter.new(arr[0..]).flat_map(ParseInt.apply);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(flat_map)));
    }
    try testing.expectEqual(@as(?u32, 1), flat_map.next());
    try testing.expectEqual(@as(?u32, 2), flat_map.next());
    try testing.expectEqual(@as(?u32, 3), flat_map.next());
    try testing.expectEqual(@as(?u32, null), flat_map.next());
}

pub fn Derive(comptime Iter: type) type {
    return struct {
        pub usingnamespace DeriveMap(Iter);
        pub usingnamespace DeriveFilter(Iter);
        pub usingnamespace DeriveFlatMap(Iter);
    };
}

test "derive" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const Triple = struct {
        pub fn apply_ref(x: *const u32) u32 {
            return x.* * 3;
        }
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
        .map(Triple.apply_ref) // derive map for SliceIter
        .filter(IsEven.apply) // more derive filter for IterMap
        .map(Triple.apply); // more more derive map for IterFilter
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(mfm)));
    }
    try testing.expectEqual(@as(?u32, 6 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, 12 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, 18 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
}
