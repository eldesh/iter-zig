const std = @import("std");
const meta = @import("./type.zig");
const iter = @import("./iter.zig");
const to_iter = @import("./to_iter.zig");
const tuple = @import("./tuple.zig");

const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

const MakeSliceIter = to_iter.MakeSliceIter;
const isIterator = meta.isIterator;

fn DeriveEnumerate(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "enumerate")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn enumerate(self: Iter) iter.Enumerate(Iter) {
                return iter.Enumerate(Iter).new(self);
            }
        };
    }
}

test "derive enumerate" {
    const tuple2 = tuple.tuple2;
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveEnumerate, u32);
    var enumerate = Iter.new(arr[0..]).enumerate();
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(enumerate)));
    }
    try testing.expectEqual(tuple2(&arr[0], @as(usize, 0)), enumerate.next().?);
    try testing.expectEqual(tuple2(&arr[1], @as(usize, 1)), enumerate.next().?);
    try testing.expectEqual(tuple2(&arr[2], @as(usize, 2)), enumerate.next().?);
    try testing.expectEqual(tuple2(&arr[3], @as(usize, 3)), enumerate.next().?);
    try testing.expectEqual(tuple2(&arr[4], @as(usize, 4)), enumerate.next().?);
    try testing.expectEqual(@as(?@TypeOf(enumerate).Item, null), enumerate.next());
}

test "derive enumerate map" {
    const Tuple2 = tuple.Tuple2;
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    var eiter = MakeSliceIter(Derive, u32).new(arr[0..]).enumerate().map(struct {
        fn proj(item: Tuple2(*u32, usize)) *u32 {
            return item.get(0);
        }
    }.proj);
    comptime {
        assert(isIterator(@TypeOf(eiter)));
    }
    try testing.expectEqual(@as(u32, 1), eiter.next().?.*);
    try testing.expectEqual(@as(u32, 2), eiter.next().?.*);
    try testing.expectEqual(@as(u32, 3), eiter.next().?.*);
    try testing.expectEqual(@as(u32, 4), eiter.next().?.*);
    try testing.expectEqual(@as(u32, 5), eiter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), eiter.next());
}

fn DeriveChain(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "chain")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn chain(self: Iter, other: anytype) iter.Chain(Iter, @TypeOf(other)) {
                return iter.Chain(Iter, @TypeOf(other)).new(self, other);
            }
        };
    }
}

test "derive chain" {
    const IsEven = struct {
        fn apply(x: *const u32) bool {
            return x.* % 2 == 0;
        }
    };
    var arr1 = [_]u32{ 1, 2, 3 };
    var arr2 = [_]u32{ 4, 5, 6 };
    const Iter1 = MakeSliceIter(DeriveFilter, u32);
    const Iter2 = MakeSliceIter(DeriveChain, u32);
    var other = Iter1.new(arr2[0..]).filter(IsEven.apply);
    var chain = Iter2.new(arr1[0..]).chain(other);
    comptime {
        assert(isIterator(Iter1));
        assert(isIterator(Iter2));
        assert(isIterator(@TypeOf(chain)));
    }
    try testing.expectEqual(@as(u32, 1), chain.next().?.*);
    try testing.expectEqual(@as(u32, 2), chain.next().?.*);
    try testing.expectEqual(@as(u32, 3), chain.next().?.*);
    try testing.expectEqual(@as(u32, 4), chain.next().?.*);
    // filter out '5' by IsEven
    try testing.expectEqual(@as(u32, 6), chain.next().?.*);
    try testing.expectEqual(@as(?*u32, null), chain.next());
}

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

fn DeriveFilterMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "flat_map")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn flat_map(self: Iter, m: anytype) iter.FilterMap(Iter, @TypeOf(m)) {
                return iter.FilterMap(Iter, @TypeOf(m)).new(m, self);
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
    const Iter = MakeSliceIter(DeriveFilterMap, []const u8);
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
        pub usingnamespace DeriveFilterMap(Iter);
        pub usingnamespace DeriveChain(Iter);
        pub usingnamespace DeriveEnumerate(Iter);
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
