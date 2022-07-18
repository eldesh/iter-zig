const std = @import("std");
const meta = @import("./type.zig");
const iter = @import("./iter.zig");
const to_iter = @import("./to_iter.zig");
const tuple = @import("./tuple.zig");
const range = @import("./range.zig");

const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

const Order = std.math.Order;

const MakeSliceIter = to_iter.MakeSliceIter;
const isIterator = meta.isIterator;

fn DeriveCmp(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "cmp")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn cmp(self: Iter, other: anytype) math.Order {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other);
            }
        };
    }
}

test "derive cmp Int" {
    const Iter = range.MakeRangeIter(DeriveCmp, u32);
    try testing.expectEqual(math.Order.eq, Iter.new(@as(u32, 2), 11, 2).cmp(Iter.new(@as(u32, 2), 11, 2)));
    try testing.expectEqual(math.Order.eq, Iter.new(@as(u32, 2), 2, 2).cmp(Iter.new(@as(u32, 2), 2, 2)));
    try testing.expectEqual(math.Order.lt, Iter.new(@as(u32, 2), 11, 2).cmp(Iter.new(@as(u32, 3), 11, 2)));
    try testing.expectEqual(math.Order.gt, Iter.new(@as(u32, 2), 11, 2).cmp(Iter.new(@as(u32, 2), 9, 2)));
}

test "derive cmp Ptr" {
    var arr1 = [_]u32{ 0, 1, 2, 3 };
    var arr2 = [_]u32{ 0, 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveCmp, u32);

    try testing.expectEqual(math.Order.eq, Iter.new(arr1[0..]).cmp(Iter.new(arr2[0..])));
    try testing.expectEqual(math.Order.eq, Iter.new(arr1[0..0]).cmp(Iter.new(arr2[0..0])));
    try testing.expectEqual(math.Order.lt, Iter.new(arr1[0..2]).cmp(Iter.new(arr2[0..3])));
    try testing.expectEqual(math.Order.gt, Iter.new(arr1[0..3]).cmp(Iter.new(arr2[0..2])));
}

fn DeriveLe(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "le")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn le(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.lte);
            }
        };
    }
}

test "derive le Int" {
    const Iter = range.MakeRangeIter(DeriveLe, u32);
    try testing.expect(Iter.new(@as(u32, 2), 11, 2).le(Iter.new(@as(u32, 2), 11, 2)));
    try testing.expect(Iter.new(@as(u32, 2), 2, 2).le(Iter.new(@as(u32, 2), 2, 2)));
    try testing.expect(Iter.new(@as(u32, 2), 11, 2).le(Iter.new(@as(u32, 3), 11, 2)));
    try testing.expect(!Iter.new(@as(u32, 2), 11, 2).le(Iter.new(@as(u32, 2), 9, 2)));
}

test "derive le Ptr" {
    var arr1 = [_]u32{ 0, 1, 2, 3 };
    var arr2 = [_]u32{ 0, 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveLe, u32);

    try testing.expect(Iter.new(arr1[0..]).le(Iter.new(arr2[0..])));
    try testing.expect(Iter.new(arr1[0..0]).le(Iter.new(arr2[0..0])));
    try testing.expect(Iter.new(arr1[0..2]).le(Iter.new(arr2[0..3])));
    try testing.expect(!Iter.new(arr1[0..3]).le(Iter.new(arr2[0..2])));
}

fn DeriveGe(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "ge")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn ge(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.gte);
            }
        };
    }
}

test "derive ge Int" {
    const Iter = range.MakeRangeIter(DeriveGe, u32);
    try testing.expect(Iter.new(@as(u32, 2), 11, 2).ge(Iter.new(@as(u32, 2), 11, 2)));
    try testing.expect(Iter.new(@as(u32, 2), 2, 2).ge(Iter.new(@as(u32, 2), 2, 2)));
    try testing.expect(!Iter.new(@as(u32, 2), 11, 2).ge(Iter.new(@as(u32, 3), 11, 2)));
    try testing.expect(Iter.new(@as(u32, 2), 11, 2).ge(Iter.new(@as(u32, 2), 9, 2)));
}

test "derive ge Ptr" {
    var arr1 = [_]u32{ 0, 1, 2, 3 };
    var arr2 = [_]u32{ 0, 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveGe, u32);

    try testing.expect(Iter.new(arr1[0..]).ge(Iter.new(arr2[0..])));
    try testing.expect(Iter.new(arr1[0..0]).ge(Iter.new(arr2[0..0])));
    try testing.expect(!Iter.new(arr1[0..2]).ge(Iter.new(arr2[0..3])));
    try testing.expect(Iter.new(arr1[0..3]).ge(Iter.new(arr2[0..2])));
}

fn DeriveLt(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "lt")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn lt(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.lt);
            }
        };
    }
}

test "derive lt Int" {
    const Iter = range.MakeRangeIter(DeriveLt, u32);
    try testing.expect(!Iter.new(@as(u32, 2), 11, 2).lt(Iter.new(@as(u32, 2), 11, 2)));
    try testing.expect(!Iter.new(@as(u32, 2), 2, 2).lt(Iter.new(@as(u32, 2), 2, 2)));
    try testing.expect(Iter.new(@as(u32, 2), 11, 2).lt(Iter.new(@as(u32, 3), 11, 2)));
    try testing.expect(!Iter.new(@as(u32, 2), 11, 2).lt(Iter.new(@as(u32, 2), 9, 2)));
}

test "derive lt Ptr" {
    var arr1 = [_]u32{ 0, 1, 2, 3 };
    var arr2 = [_]u32{ 0, 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveLt, u32);

    try testing.expect(!Iter.new(arr1[0..]).lt(Iter.new(arr2[0..])));
    try testing.expect(!Iter.new(arr1[0..0]).lt(Iter.new(arr2[0..0])));
    try testing.expect(Iter.new(arr1[0..2]).lt(Iter.new(arr2[0..3])));
    try testing.expect(!Iter.new(arr1[0..3]).lt(Iter.new(arr2[0..2])));
}

fn DeriveGt(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "gt")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn gt(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.gt);
            }
        };
    }
}

test "derive gt Int" {
    const Iter = range.MakeRangeIter(DeriveGt, u32);
    try testing.expect(!Iter.new(@as(u32, 2), 11, 2).gt(Iter.new(@as(u32, 2), 11, 2)));
    try testing.expect(!Iter.new(@as(u32, 2), 2, 2).gt(Iter.new(@as(u32, 2), 2, 2)));
    try testing.expect(!Iter.new(@as(u32, 2), 11, 2).gt(Iter.new(@as(u32, 3), 11, 2)));
    try testing.expect(Iter.new(@as(u32, 2), 11, 2).gt(Iter.new(@as(u32, 2), 9, 2)));
}

test "derive gt Ptr" {
    var arr1 = [_]u32{ 0, 1, 2, 3 };
    var arr2 = [_]u32{ 0, 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveGt, u32);

    try testing.expect(!Iter.new(arr1[0..]).gt(Iter.new(arr2[0..])));
    try testing.expect(!Iter.new(arr1[0..0]).gt(Iter.new(arr2[0..0])));
    try testing.expect(!Iter.new(arr1[0..2]).gt(Iter.new(arr2[0..3])));
    try testing.expect(Iter.new(arr1[0..3]).gt(Iter.new(arr2[0..2])));
}

fn DeriveProduct(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "product")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn product(self: Iter) error{Overflow}!iter.ProductType(Iter.Item) {
                return iter.Product(Iter.Item).product(self);
            }
        };
    }
}

test "derive product int" {
    const Iter = range.MakeRangeIter(DeriveProduct, u32);
    try testing.expectEqual(@as(u32, 3840), try Iter.new(@as(u32, 2), 11, 2).product());
    try testing.expectEqual(@as(u32, 0), try Iter.new(@as(u32, 0), 10, 1).product());
}

test "derive product ptr" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveProduct, u32);
    try testing.expectEqual(Iter.new(arr[2..4]).product(), @as(u32, 12));
    try testing.expectEqual(Iter.new(arr[0..]).product(), @as(u32, 120));
}

fn DeriveSum(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "sum")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn sum(self: Iter) error{Overflow}!iter.SumType(Iter.Item) {
                return iter.Sum(Iter.Item).sum(self);
            }
        };
    }
}

test "derive sum int" {
    const Iter = range.MakeRangeIter(DeriveSum, u32);
    try testing.expectEqual(@as(u32, 0), try Iter.new(@as(u32, 0), 0, 1).sum());
    try testing.expectEqual(@as(u32, 55), try Iter.new(@as(u32, 0), 11, 1).sum());
}

test "derive sum ptr" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveSum, u32);
    try testing.expectEqual(Iter.new(arr[0..0]).sum(), @as(u32, 0));
    try testing.expectEqual(Iter.new(arr[0..]).sum(), @as(u32, 15));
}

fn DeriveEq(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "eq")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn eq(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                var it = self;
                var jt = other;
                while (it.next()) |lval| {
                    if (jt.next()) |rval| {
                        if (std.meta.eql(lval, rval))
                            continue;
                    }
                    return false;
                }
                return jt.next() == null;
            }
        };
    }
}

test "derive eq" {
    const Iter = range.MakeRangeIter(DeriveEq, u32);
    const Range = struct {
        pub fn new(start: u32, end: u32) Iter {
            return Iter.new(start, end, 1);
        }
    };
    try testing.expect(Range.new(0, 0).eq(Range.new(0, 0)));
    try testing.expect(Range.new(1, 6).eq(Range.new(1, 6)));
    try testing.expect(!Range.new(1, 6).eq(Range.new(1, 7)));
    try testing.expect(!Range.new(1, 6).eq(Range.new(0, 0)));
}

fn DeriveNe(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "ne")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn ne(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                var it = self;
                var jt = other;
                while (it.next()) |lval| {
                    if (jt.next()) |rval| {
                        if (std.meta.eql(lval, rval))
                            continue;
                    }
                    return true;
                }
                return jt.next() != null;
            }
        };
    }
}

test "derive ne" {
    const Iter = range.MakeRangeIter(DeriveNe, u32);
    const Range = struct {
        pub fn new(start: u32, end: u32) Iter {
            return Iter.new(start, end, 1);
        }
    };
    try testing.expect(!Range.new(0, 0).ne(Range.new(0, 0)));
    try testing.expect(!Range.new(1, 6).ne(Range.new(1, 6)));
    try testing.expect(Range.new(1, 6).ne(Range.new(1, 7)));
    try testing.expect(Range.new(1, 6).ne(Range.new(0, 0)));
}

fn DeriveMax(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "max")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn max(self: Iter) ?Iter.Item {
                var it = self;
                var acc: Iter.Item = undefined;
                if (it.next()) |val| {
                    acc = val;
                } else {
                    return null;
                }
                while (it.next()) |val| {
                    // TODO: generalize to compare values of Ordered type
                    if (acc < val) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    }
}

test "derive max" {
    const Iter = range.MakeRangeIter(DeriveMax, u32);
    const max = Iter.new(@as(u32, 0), 10, 1).max();
    try testing.expectEqual(@as(?u32, 9), max);
}

test "derive max empty" {
    const Iter = range.MakeRangeIter(DeriveMax, u32);
    const max = Iter.new(@as(u32, 0), 0, 1).max();
    try testing.expectEqual(@as(?u32, null), max);
}

fn DeriveMaxBy(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "max_by")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn max_by(self: Iter, compare: fn (*const Iter.Item, *const Iter.Item) Order) ?Iter.Item {
                var it = self;
                var acc: Iter.Item = undefined;
                if (it.next()) |val| {
                    acc = val;
                } else {
                    return null;
                }
                while (it.next()) |val| {
                    if (compare(&acc, &val) == .lt) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    }
}

test "derive max_by" {
    const Iter = range.MakeRangeIter(DeriveMaxBy, u32);
    const max_by = Iter.new(@as(u32, 0), 10, 1).max_by(struct {
        fn call(x: *const u32, y: *const u32) Order {
            return math.order(x.*, y.*);
        }
    }.call);
    try testing.expectEqual(@as(?u32, 9), max_by);
}

test "derive max_by empty" {
    const Iter = range.MakeRangeIter(DeriveMaxBy, u32);
    const max_by = Iter.new(@as(u32, 0), 0, 1).max_by(struct {
        fn call(x: *const u32, y: *const u32) Order {
            return math.order(x.*, y.*);
        }
    }.call);
    try testing.expectEqual(@as(?u32, null), max_by);
}

/// Compare values of integral or pointer to integral type
/// TODO: generalize comparalable type
fn order(a: anytype, b: @TypeOf(a)) Order {
    const T = @TypeOf(a);
    if (comptime std.meta.trait.isIntegral(T)) {
        return math.order(a, b);
    }
    if (comptime std.meta.trait.is(.Pointer)(T)) {
        if (comptime std.meta.trait.isIntegral(meta.remove_pointer(T))) {
            return math.order(a.*, b.*);
        }
    }
    unreachable;
}

fn DeriveMaxByKey(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "max_by_key")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn max_by_key(self: Iter, f: anytype) ?Iter.Item {
                var it = self;
                var acc: Iter.Item = undefined;
                if (it.next()) |val| {
                    acc = val;
                } else {
                    return null;
                }
                while (it.next()) |val| {
                    if (order(f(&acc), f(&val)) == .lt) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    }
}

test "derive max_by_key" {
    const T = struct {
        id: u32,
    };
    var arr = [_]T{ .{ .id = 5 }, .{ .id = 3 }, .{ .id = 8 }, .{ .id = 0 } };
    const Iter = MakeSliceIter(DeriveMaxByKey, T);
    const max_by_key = Iter.new(arr[0..]).max_by_key(struct {
        fn call(x: *const *T) u32 {
            return x.*.id;
        }
    }.call);
    try testing.expectEqual(T{ .id = 8 }, max_by_key.?.*);
}

test "derive max_by_key empty" {
    const T = struct {
        id: u32,
    };
    var arr = [_]T{};
    const Iter = MakeSliceIter(DeriveMaxByKey, T);
    const max_by_key = Iter.new(arr[0..]).max_by_key(struct {
        fn call(x: *const *T) u32 {
            return x.*.id;
        }
    }.call);
    try testing.expectEqual(@as(?*T, null), max_by_key);
}

fn DeriveMin(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "min")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn min(self: Iter) ?Iter.Item {
                var it = self;
                var acc: Iter.Item = undefined;
                if (it.next()) |val| {
                    acc = val;
                } else {
                    return null;
                }
                while (it.next()) |val| {
                    // TODO: generalize to compare values of Ordered type
                    if (acc > val) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    }
}

test "derive min" {
    const Iter = range.MakeRangeIter(DeriveMin, u32);
    const min = Iter.new(@as(u32, 0), 10, 1).min();
    try testing.expectEqual(@as(?u32, 0), min);
}

test "derive min empty" {
    const Iter = range.MakeRangeIter(DeriveMin, u32);
    const min = Iter.new(@as(u32, 0), 0, 1).min();
    try testing.expectEqual(@as(?u32, null), min);
}

fn DeriveMinBy(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "min_by")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn min_by(self: Iter, compare: fn (*const Iter.Item, *const Iter.Item) Order) ?Iter.Item {
                var it = self;
                var acc: Iter.Item = undefined;
                if (it.next()) |val| {
                    acc = val;
                } else {
                    return null;
                }
                while (it.next()) |val| {
                    if (compare(&acc, &val) == .gt) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    }
}

test "derive min_by" {
    const Iter = range.MakeRangeIter(DeriveMinBy, u32);
    const min_by = Iter.new(@as(u32, 0), 10, 1).min_by(struct {
        fn call(x: *const u32, y: *const u32) Order {
            return math.order(x.*, y.*);
        }
    }.call);
    try testing.expectEqual(@as(?u32, 0), min_by);
}

test "derive min_by empty" {
    const Iter = range.MakeRangeIter(DeriveMinBy, u32);
    const min_by = Iter.new(@as(u32, 0), 0, 1).min_by(struct {
        fn call(x: *const u32, y: *const u32) Order {
            return math.order(x.*, y.*);
        }
    }.call);
    try testing.expectEqual(@as(?u32, null), min_by);
}

fn DeriveMinByKey(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "min_by_key")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn min_by_key(self: Iter, f: anytype) ?Iter.Item {
                var it = self;
                var acc: Iter.Item = undefined;
                if (it.next()) |val| {
                    acc = val;
                } else {
                    return null;
                }
                while (it.next()) |val| {
                    if (order(f(&acc), f(&val)) == .gt) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    }
}

test "derive min_by_key" {
    const T = struct {
        id: u32,
    };
    var arr = [_]T{ .{ .id = 5 }, .{ .id = 3 }, .{ .id = 8 }, .{ .id = 0 } };
    const Iter = MakeSliceIter(DeriveMinByKey, T);
    const min_by_key = Iter.new(arr[0..]).min_by_key(struct {
        fn call(x: *const *T) u32 {
            return x.*.id;
        }
    }.call);
    try testing.expectEqual(T{ .id = 0 }, min_by_key.?.*);
}

test "derive min_by_key empty" {
    const T = struct {
        id: u32,
    };
    var arr = [_]T{};
    const Iter = MakeSliceIter(DeriveMinByKey, T);
    const min_by_key = Iter.new(arr[0..]).min_by_key(struct {
        fn call(x: *const *T) u32 {
            return x.*.id;
        }
    }.call);
    try testing.expectEqual(@as(?*T, null), min_by_key);
}

fn DeriveStepBy(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "step_by")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn step_by(self: Iter, skip: usize) iter.StepBy(Iter) {
                return iter.StepBy(Iter).new(self, skip);
            }
        };
    }
}

test "derive skip_by" {
    var arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveStepBy, u32);
    var skip = Iter.new(arr[0..]).step_by(2);
    try testing.expectEqual(@as(u32, 0), skip.next().?.*);
    try testing.expectEqual(@as(u32, 2), skip.next().?.*);
    try testing.expectEqual(@as(u32, 4), skip.next().?.*);
    try testing.expectEqual(@as(?*u32, null), skip.next());
    try testing.expectEqual(@as(?*u32, null), skip.next());
}

fn DeriveFuse(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "fuse")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn fuse(self: Iter) iter.Fuse(Iter) {
                return iter.Fuse(Iter).new(self);
            }
        };
    }
}

test "derive fuse" {
    // 0, 1, 2, null, 4, null, 6, null, ..
    const Even = struct {
        pub const Self: type = @This();
        pub const Item: type = u32;
        pub usingnamespace DeriveFuse(@This());
        val: u32,
        pub fn next(self: *Self) ?Item {
            if (self.val <= 2 or self.val % 2 == 0) {
                const val = self.val;
                self.val += 1;
                return val;
            } else {
                self.val += 1;
                return null;
            }
        }
    };
    var fuse = (Even{ .val = 0 }).fuse();
    try testing.expectEqual(@as(?u32, 0), fuse.next());
    try testing.expectEqual(@as(?u32, 1), fuse.next());
    try testing.expectEqual(@as(?u32, 2), fuse.next());
    try testing.expectEqual(@as(?u32, null), fuse.next());
    try testing.expectEqual(@as(?u32, null), fuse.next());
    try testing.expectEqual(@as(?u32, null), fuse.next());
}

fn DeriveScan(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "scan")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn scan(self: Iter, st: anytype, f: anytype) iter.Scan(Iter, @TypeOf(st), @TypeOf(f)) {
                return iter.Scan(Iter, @TypeOf(st), @TypeOf(f)).new(self, st, f);
            }
        };
    }
}

test "derive scan" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveScan, u32);
    var scan = Iter.new(arr[0..]).scan(@as(u32, 100), struct {
        fn call(st: *u32, v: *u32) ?i64 {
            st.* += v.*;
            return -@as(i64, st.*);
        }
    }.call);
    try testing.expectEqual(@as(i64, -101), scan.next().?);
    try testing.expectEqual(@as(i64, -103), scan.next().?);
    try testing.expectEqual(@as(i64, -106), scan.next().?);
    try testing.expectEqual(@as(i64, -110), scan.next().?);
    try testing.expectEqual(@as(i64, -115), scan.next().?);
    try testing.expectEqual(@as(?i64, null), scan.next());
}

fn DeriveSkip(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "skip")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn skip(self: Iter, size: usize) iter.Skip(Iter) {
                return iter.Skip(Iter).new(self, size);
            }
        };
    }
}

test "derive skip" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveSkip, u32);
    var skip = Iter.new(arr[0..]).skip(3);
    try testing.expectEqual(@as(u32, 4), skip.next().?.*);
    try testing.expectEqual(@as(u32, 5), skip.next().?.*);
    try testing.expectEqual(@as(?*u32, null), skip.next());
}

test "derive skip over" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveSkip, u32);
    var skip = Iter.new(arr[0..]).skip(10);
    try testing.expectEqual(@as(?*u32, null), skip.next());
    try testing.expectEqual(@as(?*u32, null), skip.next());
    try testing.expectEqual(@as(?*u32, null), skip.next());
}

fn DeriveReduce(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "reduce")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn reduce(self: Iter, f: fn (Iter.Item, Iter.Item) Iter.Item) ?Iter.Item {
                var it = self;
                var fst = it.next();
                if (fst == null)
                    return null;

                var acc = fst.?;
                while (it.next()) |value| {
                    acc = f(acc, value);
                }
                return acc;
            }
        };
    }
}

test "derive reduce" {
    const Iter = range.MakeRangeIter(DeriveReduce, u32);
    const sum = Iter.new(@as(u32, 0), 10, 1).reduce(struct {
        fn call(acc: u32, val: u32) u32 {
            return acc + val;
        }
    }.call);
    try testing.expectEqual(@as(?u32, 45), sum);
}

fn DeriveFold(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "fold")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn fold(self: Iter, init: anytype, f: fn (@TypeOf(init), Iter.Item) @TypeOf(init)) @TypeOf(init) {
                var it = self;
                var acc = init;
                while (it.next()) |value| {
                    acc = f(acc, value);
                }
                return acc;
            }
        };
    }
}

test "derive fold" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveFold, u32);
    const sum = Iter.new(arr[0..]).fold(@as(u32, 0), struct {
        fn call(acc: u32, val: *const u32) u32 {
            return acc + val.*;
        }
    }.call);
    try testing.expectEqual(@as(u32, 15), sum);
}

fn DeriveForeach(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "for_each")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn for_each(self: Iter, f: fn (Iter.Item) void) void {
                var it = self;
                while (it.next()) |value| {
                    f(value);
                }
            }
        };
    }
}

test "derive for_each" {
    try struct {
        var i: u32 = 0;
        fn call(x: *u32) void {
            i += x.*;
        }
        fn dotest() !void {
            var arr = [_]u32{ 1, 2, 3, 4, 5 };
            const Iter = MakeSliceIter(DeriveForeach, u32);
            Iter.new(arr[0..]).for_each(call);
            try testing.expectEqual(@as(?u32, 15), i);
        }
    }.dotest();
}

fn DeriveMapWhile(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "map_while")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn map_while(self: Iter, pred: anytype) iter.MapWhile(Iter, @TypeOf(pred)) {
                return iter.MapWhile(Iter, @TypeOf(pred)).new(self, pred);
            }
        };
    }
}

test "derive map_while" {
    var arr = [_][]const u8{ "1", "2abc", "3" };
    const Iter = MakeSliceIter(DeriveMapWhile, []const u8);
    var map_while = Iter.new(arr[0..]).map_while(struct {
        fn call(buf: *[]const u8) ?u32 {
            return std.fmt.parseInt(u32, buf.*, 10) catch null;
        }
    }.call);
    try testing.expectEqual(@as(?u32, 1), map_while.next().?);
    try testing.expectEqual(@as(?u32, null), map_while.next());
    try testing.expectEqual(@as(?u32, 3), map_while.next().?);
    try testing.expectEqual(@as(?u32, null), map_while.next());
}

fn DeriveInspect(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "inspect")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn inspect(self: Iter, f: fn (*const Iter.Item) void) iter.Inspect(Iter) {
                return iter.Inspect(Iter).new(self, f);
            }
        };
    }
}

test "derive inspect" {
    try struct {
        var i: u32 = 0;
        fn call(x: *const *u32) void {
            _ = x;
            i += 1;
        }
        fn dotest() !void {
            var arr = [_]u32{ 1, 2, 3, 4, 5 };
            const Iter = MakeSliceIter(DeriveInspect, u32);
            var inspect = Iter.new(arr[0..]).inspect(call);
            try testing.expectEqual(@as(u32, 1), inspect.next().?.*);
            try testing.expectEqual(@as(u32, 1), i);
            try testing.expectEqual(@as(u32, 2), inspect.next().?.*);
            try testing.expectEqual(@as(u32, 2), i);
            try testing.expectEqual(@as(u32, 3), inspect.next().?.*);
            try testing.expectEqual(@as(u32, 3), i);
            try testing.expectEqual(@as(u32, 4), inspect.next().?.*);
            try testing.expectEqual(@as(u32, 4), i);
            try testing.expectEqual(@as(u32, 5), inspect.next().?.*);
            try testing.expectEqual(@as(u32, 5), i);
            try testing.expectEqual(@as(?*u32, null), inspect.next());
            try testing.expectEqual(@as(u32, 5), i);
            try testing.expectEqual(@as(?*u32, null), inspect.next());
            try testing.expectEqual(@as(u32, 5), i);
        }
    }.dotest();
}

fn DeriveFindMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "find_map")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn find_map(self: *Iter, f: anytype) iter.codomain(@TypeOf(f)) {
                while (self.next()) |val| {
                    if (f(val)) |mval| {
                        return mval;
                    }
                }
                return null;
            }
        };
    }
}

test "derive find_map" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveFindMap, u32);
    try testing.expectEqual(Iter.new(arr[0..]).find_map(struct {
        fn call(x: *u32) ?u32 {
            return if (x.* > 3) x.* * 2 else null;
        }
    }.call), 8);
    try testing.expectEqual(Iter.new(arr[0..]).find_map(struct {
        fn call(x: *u32) ?u32 {
            return if (x.* > 10) x.* * 2 else null;
        }
    }.call), null);
}

fn DeriveFind(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "find")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn find(self: *Iter, p: anytype) ?Iter.Item {
                while (self.next()) |val| {
                    if (p(&val))
                        return val;
                }
                return null;
            }
        };
    }
}

test "derive find" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveFind, u32);
    try testing.expectEqual(Iter.new(arr[0..]).find(struct {
        fn call(x: *const *u32) bool {
            return x.*.* > 3;
        }
    }.call).?.*, 4);
}

fn DeriveCount(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "count")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn count(self: *Iter) usize {
                var i: usize = 0;
                while (self.next()) |_| {
                    i += 1;
                }
                return i;
            }
        };
    }
}

test "derive count" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveCount, u32);
    try testing.expectEqual(Iter.new(arr[0..0]).count(), 0);
    try testing.expectEqual(Iter.new(arr[0..]).count(), arr[0..].len);
}

fn DeriveAll(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "all")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn all(self: *Iter, P: fn (*const Iter.Item) bool) bool {
                while (self.next()) |val| {
                    if (!P(&val))
                        return false;
                }
                return true;
            }
        };
    }
}

test "derive all" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveAll, u32);
    try testing.expect(Iter.new(arr[0..]).all(struct {
        fn less10(x: *const *u32) bool {
            return x.*.* < 10;
        }
    }.less10));
    try testing.expect(!Iter.new(arr[0..]).all(struct {
        fn greater10(x: *const *u32) bool {
            return x.*.* > 10;
        }
    }.greater10));
}

fn DeriveAny(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "any")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn any(self: *Iter, P: fn (*const Iter.Item) bool) bool {
                while (self.next()) |val| {
                    if (P(&val))
                        return true;
                }
                return false;
            }
        };
    }
}

test "derive any" {
    var arr = [_]u32{ 1, 2, 3, 4, 5 };
    const Iter = MakeSliceIter(DeriveAny, u32);
    try testing.expect(Iter.new(arr[0..]).any(struct {
        fn greater4(x: *const *u32) bool {
            return x.*.* > 4;
        }
    }.greater4));
    try testing.expect(!Iter.new(arr[0..]).any(struct {
        fn greater10(x: *const *u32) bool {
            return x.*.* > 10;
        }
    }.greater10));
}

fn DeriveTake(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "take")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn take(self: Iter, size: usize) iter.Take(Iter) {
                return iter.Take(Iter).new(self, size);
            }
        };
    }
}

test "derive take" {
    var arr = [_]i32{ -3, -2, -1, 0, 1, -2, -3, 4, 5 };
    const Iter = MakeSliceIter(struct {
        fn derive(comptime T: type) type {
            return struct {
                pub usingnamespace DeriveTake(T);
                pub usingnamespace DeriveFilter(T);
            };
        }
    }.derive, i32);
    var take = Iter.new(arr[0..]).filter(struct {
        fn call(v: *i32) bool {
            return v.* < 0;
        }
    }.call).take(6);
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(take)));
    }
    try testing.expectEqual(@as(i32, -3), take.next().?.*);
    try testing.expectEqual(@as(i32, -2), take.next().?.*);
    try testing.expectEqual(@as(i32, -1), take.next().?.*);
    try testing.expectEqual(@as(?@TypeOf(take).Item, null), take.next());
    try testing.expectEqual(@as(?@TypeOf(take).Item, null), take.next());
    // 6th (the last of 'take(6)') element
    try testing.expectEqual(@as(i32, -2), take.next().?.*);
    // After this, no more non-null values will be returned.
    try testing.expectEqual(@as(?@TypeOf(take).Item, null), take.next());
    try testing.expectEqual(@as(?@TypeOf(take).Item, null), take.next());
    try testing.expectEqual(@as(?@TypeOf(take).Item, null), take.next());
}

fn DeriveTakeWhile(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "take_while")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn take_while(self: Iter, pred: anytype) iter.TakeWhile(Iter, @TypeOf(pred)) {
                return iter.TakeWhile(Iter, @TypeOf(pred)).new(self, pred);
            }
        };
    }
}

test "derive take_while" {
    var arr = [_]i32{ -3, -2, -1, 0, 1, -2, -3, 4, 5 };
    const Iter = MakeSliceIter(DeriveTakeWhile, i32);
    var take_while = Iter.new(arr[0..]).take_while(struct {
        fn call(v: *const *i32) bool {
            return v.*.* <= 0;
        }
    }.call);
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(take_while)));
    }
    try testing.expectEqual(@as(i32, -3), take_while.next().?.*);
    try testing.expectEqual(@as(i32, -2), take_while.next().?.*);
    try testing.expectEqual(@as(i32, -1), take_while.next().?.*);
    try testing.expectEqual(@as(i32, 0), take_while.next().?.*);
    try testing.expectEqual(@as(?@TypeOf(take_while).Item, null), take_while.next());
    try testing.expectEqual(@as(?@TypeOf(take_while).Item, null), take_while.next());
    try testing.expectEqual(@as(?@TypeOf(take_while).Item, null), take_while.next());
    try testing.expectEqual(@as(?@TypeOf(take_while).Item, null), take_while.next());
}

fn DeriveSkipWhile(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "skip_while")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn skip_while(self: Iter, pred: anytype) iter.SkipWhile(Iter, @TypeOf(pred)) {
                return iter.SkipWhile(Iter, @TypeOf(pred)).new(self, pred);
            }
        };
    }
}

test "derive skip_while" {
    var arr = [_]i32{ 2, 1, 0, -1, 2, 3, -1, 2 };
    const Iter = MakeSliceIter(DeriveSkipWhile, i32);
    var skip_while = Iter.new(arr[0..]).skip_while(struct {
        fn call(v: *const *i32) bool {
            return v.*.* >= 0;
        }
    }.call);
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(skip_while)));
    }
    try testing.expectEqual(@as(i32, -1), skip_while.next().?.*);
    try testing.expectEqual(@as(i32, 2), skip_while.next().?.*);
    try testing.expectEqual(@as(i32, 3), skip_while.next().?.*);
    try testing.expectEqual(@as(i32, -1), skip_while.next().?.*);
    try testing.expectEqual(@as(i32, 2), skip_while.next().?.*);
    try testing.expectEqual(@as(?@TypeOf(skip_while).Item, null), skip_while.next());
}

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
        fn call(x: *const u32) bool {
            return x.* % 2 == 0;
        }
    };
    var arr1 = [_]u32{ 1, 2, 3 };
    var arr2 = [_]u32{ 4, 5, 6 };
    const Iter1 = MakeSliceIter(DeriveFilter, u32);
    const Iter2 = MakeSliceIter(DeriveChain, u32);
    var other = Iter1.new(arr2[0..]).filter(IsEven.call);
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
    try testing.expectEqual(@as(?*u32, null), chain.next());
    try testing.expectEqual(@as(u32, 6), chain.next().?.*);
    try testing.expectEqual(@as(?*u32, null), chain.next());
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
        fn call(x: *const u32) bool {
            return x.* % 2 == 0;
        }
    };
    const Iter = MakeSliceIter(DeriveFilter, u32);
    var filter = Iter.new(arr[0..]).filter(IsEven.call);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(filter)));
    }
    try testing.expectEqual(@as(?*u32, null), filter.next());
    try testing.expectEqual(@as(u32, 2), filter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), filter.next());
    try testing.expectEqual(@as(u32, 4), filter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), filter.next());
    try testing.expectEqual(@as(u32, 6), filter.next().?.*);
    try testing.expectEqual(@as(?*u32, null), filter.next());
    try testing.expectEqual(@as(?*u32, null), filter.next());
}

fn DeriveFilterMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "filter_map")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn filter_map(self: Iter, m: anytype) iter.FilterMap(Iter, @TypeOf(m)) {
                return iter.FilterMap(Iter, @TypeOf(m)).new(m, self);
            }
        };
    }
}

test "derive filter_map" {
    var arr = [_][]const u8{ "1", "2", "foo", "3", "bar" };
    const ParseInt = struct {
        fn call(x: *const []const u8) ?u32 {
            return std.fmt.parseInt(u32, x.*, 10) catch null;
        }
    };
    const Iter = MakeSliceIter(DeriveFilterMap, []const u8);
    var filter_map = Iter.new(arr[0..]).filter_map(ParseInt.call);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(filter_map)));
    }
    try testing.expectEqual(@as(?u32, 1), filter_map.next());
    try testing.expectEqual(@as(?u32, 2), filter_map.next());
    try testing.expectEqual(@as(?u32, null), filter_map.next());
    try testing.expectEqual(@as(?u32, 3), filter_map.next());
    try testing.expectEqual(@as(?u32, null), filter_map.next());
    try testing.expectEqual(@as(?u32, null), filter_map.next());
    try testing.expectEqual(@as(?u32, null), filter_map.next());
}

pub fn Derive(comptime Iter: type) type {
    return struct {
        pub usingnamespace DeriveCmp(Iter);
        pub usingnamespace DeriveLe(Iter);
        pub usingnamespace DeriveGe(Iter);
        pub usingnamespace DeriveLt(Iter);
        pub usingnamespace DeriveGt(Iter);
        pub usingnamespace DeriveSum(Iter);
        pub usingnamespace DeriveProduct(Iter);
        pub usingnamespace DeriveEq(Iter);
        pub usingnamespace DeriveNe(Iter);
        pub usingnamespace DeriveMax(Iter);
        pub usingnamespace DeriveMaxBy(Iter);
        pub usingnamespace DeriveMaxByKey(Iter);
        pub usingnamespace DeriveMin(Iter);
        pub usingnamespace DeriveMinBy(Iter);
        pub usingnamespace DeriveMinByKey(Iter);
        pub usingnamespace DeriveReduce(Iter);
        pub usingnamespace DeriveSkip(Iter);
        pub usingnamespace DeriveScan(Iter);
        pub usingnamespace DeriveStepBy(Iter);
        pub usingnamespace DeriveFold(Iter);
        pub usingnamespace DeriveForeach(Iter);
        pub usingnamespace DeriveTakeWhile(Iter);
        pub usingnamespace DeriveSkipWhile(Iter);
        pub usingnamespace DeriveMap(Iter);
        pub usingnamespace DeriveMapWhile(Iter);
        pub usingnamespace DeriveFilter(Iter);
        pub usingnamespace DeriveFilterMap(Iter);
        pub usingnamespace DeriveChain(Iter);
        pub usingnamespace DeriveEnumerate(Iter);
        pub usingnamespace DeriveAll(Iter);
        pub usingnamespace DeriveAny(Iter);
        pub usingnamespace DeriveTake(Iter);
        pub usingnamespace DeriveCount(Iter);
        pub usingnamespace DeriveFind(Iter);
        pub usingnamespace DeriveFindMap(Iter);
        pub usingnamespace DeriveInspect(Iter);
        pub usingnamespace DeriveFuse(Iter);
    };
}

test "derive" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6 };
    var arr2 = [_]u32{ 30, 10, 20 };
    const Triple = struct {
        pub fn call_ref(x: *const u32) u32 {
            return x.* * 3;
        }
        pub fn call(x: u32) u32 {
            return x * 3;
        }
    };
    const IsEven = struct {
        pub fn call(x: u32) bool {
            return x % 2 == 0;
        }
    };
    const Less = struct {
        pub fn call(x: u32) ?u32 {
            return if (x < 100) x else null;
        }
    };
    const Iter = MakeSliceIter(Derive, u32);
    var mfm = Iter.new(arr[0..]).chain(Iter.new(arr2[0..]))
        .map(Triple.call_ref) // derive map for SliceIter
        .filter(IsEven.call) // more derive filter for IterMap
        .map(Triple.call) // more more derive map for IterFilter
        .filter_map(Less.call);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(mfm)));
    }
    try testing.expectEqual(@as(?u32, null), mfm.next());
    try testing.expectEqual(@as(?u32, 6 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
    try testing.expectEqual(@as(?u32, 12 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
    try testing.expectEqual(@as(?u32, 18 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
    try testing.expectEqual(@as(?u32, 30 * 3), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
    try testing.expectEqual(@as(?u32, null), mfm.next());
}
