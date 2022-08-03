const std = @import("std");
const meta = @import("./meta.zig");
const iter = @import("./iter.zig");
const to_iter = @import("./to_iter.zig");
const tuple = @import("./tuple.zig");
const range = @import("./range.zig");

const PartialEq = meta.PartialEq;
const trait = std.meta.trait;
const math = std.math;
const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

const MakeSliceIter = to_iter.MakeSliceIter;
const isIterator = meta.isIterator;

fn DerivePeekable(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "peekable")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn peekable(self: Iter) iter.Peekable(Iter) {
                return iter.Peekable(Iter).new(self);
            }
        };
    }
}

comptime {
    const Iter = range.MakeRangeIter(DerivePeekable, u32);
    assert(isIterator(Iter));
}

test "derive peekable" {
    {
        var arr = [_]i32{ 1, 0, -1, 2 };
        const Iter = MakeSliceIter(DerivePeekable, i32);
        var peek = Iter.new(arr[0..]).peekable();

        try comptime testing.expectEqual(?*const *i32, @TypeOf(peek.peek()));
        try testing.expectEqual(@as(*i32, &arr[0]), peek.peek().?.*);
        try testing.expectEqual(@as(*i32, &arr[0]), peek.peek().?.*);
        try testing.expectEqual(@as(?*i32, &arr[0]), peek.next());
        try testing.expectEqual(@as(?*i32, &arr[1]), peek.next());
        try testing.expectEqual(@as(*i32, &arr[2]), peek.peek().?.*);
        try testing.expectEqual(@as(?*i32, &arr[2]), peek.next());
        try testing.expectEqual(@as(?*i32, &arr[3]), peek.next());
        try testing.expectEqual(@as(?*i32, null), peek.next());
    }
}

fn DerivePosition(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "position")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn position(self: *Iter, predicate: fn (Iter.Item) bool) ?usize {
                var idx: usize = 0;
                while (self.next()) |val| : (idx += 1) {
                    if (predicate(val))
                        return idx;
                }
                return null;
            }
        };
    }
}

comptime {
    const Iter = range.MakeRangeIter(DerivePosition, u32);
    assert(isIterator(Iter));
}

test "derive position" {
    {
        const Iter = MakeSliceIter(DerivePosition, i32);
        var arr = [_]i32{ 1, 0, -1, 2, 3, -2 };
        try testing.expectEqual(@as(?usize, 2), Iter.new(arr[0..]).position(struct {
            fn p(x: *const i32) bool {
                return x.* < 0;
            }
        }.p));
    }
    {
        const Iter = MakeSliceIter(DerivePosition, i32);
        var arr = [_]i32{ 1, 0, -1, 2, 3, -2 };
        try testing.expectEqual(@as(?usize, null), Iter.new(arr[0..]).position(struct {
            fn p(x: *const i32) bool {
                return x.* > 10;
            }
        }.p));
    }
}

fn DeriveCycle(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "cycle")) |_| {
        return struct {};
    } else if (meta.isClonable(Iter)) {
        return struct {
            pub fn cycle(self: Iter) iter.Cycle(Iter) {
                return iter.Cycle(Iter).new(self);
            }
        };
    } else {
        return struct {};
    }
}

comptime {
    const Iter = range.MakeRangeIter(DeriveCycle, u32);
    assert(isIterator(Iter));
    assert(meta.isClonable(Iter));
}

comptime {
    const Iter = to_iter.MakeSliceIter(DeriveCycle, u32);
    assert(isIterator(Iter));
    assert(!meta.isClonable(Iter));
}

test "derive cycle" {
    const Iter = range.MakeRangeIter(DeriveCycle, u32);
    {
        var cycle = Iter.new(@as(u32, 1), 4, 1).cycle();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(cycle)));
        }
        try testing.expectEqual(@as(?u32, 1), cycle.next());
        try testing.expectEqual(@as(?u32, 2), cycle.next());
        try testing.expectEqual(@as(?u32, 3), cycle.next());
        try testing.expectEqual(@as(?u32, 1), cycle.next());
        try testing.expectEqual(@as(?u32, 2), cycle.next());
        try testing.expectEqual(@as(?u32, 3), cycle.next());
        try testing.expectEqual(@as(?u32, 1), cycle.next());
        try testing.expectEqual(@as(?u32, 2), cycle.next());
        try testing.expectEqual(@as(?u32, 3), cycle.next());
    }
    {
        var cycle = Iter.new(@as(u32, 1), 1, 1).cycle();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(cycle)));
        }
        try testing.expectEqual(@as(?u32, null), cycle.next());
    }
}

fn DeriveCopied(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "copied")) |_| {
        return struct {};
    } else if (meta.isCopyable(Iter.Item)) {
        return struct {
            pub fn copied(self: Iter) iter.Copied(Iter) {
                return iter.Copied(Iter).new(self);
            }
        };
    } else {
        return struct {};
    }
}

comptime {
    const Iter = MakeSliceIter(DeriveCopied, u32);
    assert(isIterator(Iter));
    assert(meta.isCopyable(Iter.Item));
}

test "derive copied" {
    {
        var arr = [_]u32{ 2, 3, 4 };
        const Iter = MakeSliceIter(DeriveCopied, u32);
        var copied = Iter.new(arr[0..]).copied();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(copied)));
        }
        try testing.expectEqual(@as(?u32, 2), copied.next());
        try testing.expectEqual(@as(?u32, 3), copied.next());
        try testing.expectEqual(@as(?u32, 4), copied.next());
        try testing.expectEqual(@as(?u32, null), copied.next());
    }
    {
        const R = union(enum) {
            Ok: u32,
            Err: u32,
        };
        var arr = [_]R{ .{ .Ok = 5 }, .{ .Err = 4 }, .{ .Ok = 0 } };
        const Iter = MakeSliceIter(DeriveCopied, R);
        var copied = Iter.new(arr[0..]).copied();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(copied)));
        }
        try testing.expectEqual(R{ .Ok = 5 }, copied.next().?);
        try testing.expectEqual(R{ .Err = 4 }, copied.next().?);
        try testing.expectEqual(R{ .Ok = 0 }, copied.next().?);
        try testing.expectEqual(@as(?R, null), copied.next());
    }
}

fn DeriveCloned(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "cloned")) |_| {
        return struct {};
    } else if (meta.isClonable(Iter.Item)) {
        return struct {
            pub fn cloned(self: Iter) iter.Cloned(Iter) {
                return iter.Cloned(Iter).new(self);
            }
        };
    } else {
        return struct {};
    }
}

comptime {
    const Iter = MakeSliceIter(DeriveCloned, []const u8);
    assert(isIterator(Iter));
    // []const u8 is not Clonable,
    assert(!meta.isClonable(Iter.Item));
    // then the Iter.cloned() is not derived.
    assert(meta.have_fun(Iter, "cloned") == null);
}

comptime {
    const Iter = MakeSliceIter(DeriveCloned, u32);
    assert(isIterator(Iter));
    assert(meta.isClonable(Iter.Item));
    assert(meta.have_type(Iter, "Self") == Iter);
    // Strangely, for some reason, it's an error
    // assert(meta.have_fun(Iter, "cloned") != null);
    assert(!meta.isClonable(Iter));
}

test "derive cloned" {
    {
        var arr = [_]u32{ 2, 3, 4 };
        const Iter = comptime MakeSliceIter(DeriveCloned, u32);
        var cloned = Iter.new(arr[0..]).cloned();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(cloned)));
        }
        try testing.expectEqual(@as(u32, 2), try cloned.next().?);
        try testing.expectEqual(@as(u32, 3), try cloned.next().?);
        try testing.expectEqual(@as(u32, 4), try cloned.next().?);
        // zig test src/main.zig
        // Code Generation [1628/1992] std.fmt.formatType... broken LLVM module found: Call parameter type does not match function signature!
        //   %12 = alloca %"?type.Err!u32", align 4
        //  %"?derive.error:47:38!u32"*  %22 = call fastcc i16 @std.testing.expectEqual.96(%std.builtin.StackTrace* %0, %"?derive.error:47:38!u32"* @352, %"?type.Err!u32"* %12), !dbg !4571
        //
        // This is a bug in the Zig compiler.thread 51428 panic:
        // Unable to dump stack trace: debug info stripped
        // Aborted
        // try testing.expectEqual(@as(?(error{}!u32), null), cloned.next());
        try testing.expectEqual(@as(?(meta.Clone.EmptyError!u32), null), cloned.next());
    }
    {
        const R = union(enum) {
            Ok: u32,
            Err: u32,
        };
        var arr = [_]R{ .{ .Ok = 5 }, .{ .Err = 4 }, .{ .Ok = 0 } };
        const Iter = MakeSliceIter(DeriveCloned, R);
        var cloned = Iter.new(arr[0..]).cloned();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(cloned)));
            assert(iter.err_type(meta.Clone.ResultType(R)) == meta.Clone.EmptyError);
        }
        try testing.expectEqual(R{ .Ok = 5 }, try cloned.next().?);
        try testing.expectEqual(R{ .Err = 4 }, try cloned.next().?);
        try testing.expectEqual(R{ .Ok = 0 }, try cloned.next().?);
        try testing.expectEqual(@as(?meta.Clone.EmptyError!R, null), cloned.next());
    }
    {
        const T = struct {
            pub const Self: type = @This();
            pub const CloneError: type = error{CloneError};
            val: u32,
            pub fn new(val: u32) Self {
                return .{ .val = val };
            }
            pub fn clone(self: Self) CloneError!Self {
                if (self.val == 10)
                    return CloneError.CloneError;
                return Self.new(self.val);
            }
        };
        var arr = [_]T{ .{ .val = 9 }, .{ .val = 10 }, .{ .val = 11 } };
        const Iter = MakeSliceIter(DeriveCloned, T);
        var cloned = Iter.new(arr[0..]).cloned();
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(cloned)));
        }
        try testing.expectEqual(T{ .val = 9 }, try cloned.next().?);
        try testing.expectEqual(@as(T.CloneError!T, T.CloneError.CloneError), cloned.next().?);
        try testing.expectEqual(T{ .val = 11 }, try cloned.next().?);
        try testing.expectEqual(@as(?T.CloneError!T, null), cloned.next());
    }
}

fn DeriveZip(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "zip")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn zip(self: Iter, other: anytype) iter.Zip(Iter, @TypeOf(other)) {
                return iter.Zip(Iter, @TypeOf(other)).new(self, other);
            }
        };
    }
}

test "derive zip" {
    const R = union(enum) {
        Ok: u32,
        Err: u32,
    };
    {
        var arr1 = [_]u32{ 2, 3, 4 };
        var arr2 = [_]R{ .{ .Ok = 5 }, .{ .Err = 4 }, .{ .Ok = 0 } };
        const Iter = MakeSliceIter(DeriveZip, u32);
        var zip = Iter.new(arr1[0..]).zip(to_iter.SliceIter(R).new(arr2[0..]));
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(zip)));
        }
        const t = tuple.Tuple2(*u32, *R).new;
        try testing.expectEqual(t(&arr1[0], &arr2[0]), zip.next().?);
        try testing.expectEqual(t(&arr1[1], &arr2[1]), zip.next().?);
        try testing.expectEqual(t(&arr1[2], &arr2[2]), zip.next().?);
        try testing.expectEqual(@as(?tuple.Tuple2(*u32, *R), null), zip.next());
    }
    {
        var arr1 = [_]u32{ 2, 3, 4 };
        const Iter = MakeSliceIter(DeriveZip, u32);
        var zip = Iter.new(arr1[0..]).zip(range.range(@as(u64, 3), 10, 2));
        comptime {
            assert(isIterator(Iter));
            assert(isIterator(@TypeOf(zip)));
        }
        const t = tuple.Tuple2(*u32, u64).new;
        try testing.expectEqual(t(&arr1[0], 3), zip.next().?);
        try testing.expectEqual(t(&arr1[1], 5), zip.next().?);
        try testing.expectEqual(t(&arr1[2], 7), zip.next().?);
        try testing.expectEqual(@as(?tuple.Tuple2(*u32, u64), null), zip.next());
    }
}

fn DeriveLast(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "last")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn last(self: Iter) ?Iter.Item {
                var it = self;
                var ls: ?Iter.Item = null;
                while (it.next()) |val| {
                    ls = val;
                }
                return ls;
            }
        };
    }
}

test "derive last" {
    {
        var arr = [_]u32{ 2, 3, 4 };
        const Iter = MakeSliceIter(DeriveLast, u32);
        comptime {
            assert(isIterator(Iter));
        }
        try testing.expectEqual(@as(u32, 4), Iter.new(arr[0..]).last().?.*);
    }
    {
        var arr = [_]u32{};
        const Iter = MakeSliceIter(DeriveLast, u32);
        comptime {
            assert(isIterator(Iter));
        }
        try testing.expectEqual(@as(?*u32, null), Iter.new(arr[0..]).last());
    }
}

fn DeriveNth(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "nth")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn nth(self: Iter, n: usize) ?Iter.Item {
                var it = self;
                var i = @as(usize, 0);
                while (i < n) : (i += 1) {
                    _ = it.next();
                }
                return it.next();
            }
        };
    }
}

test "derive nth" {
    var arr = [_]u32{ 2, 3, 4 };
    const Iter = MakeSliceIter(DeriveNth, u32);
    comptime {
        assert(isIterator(Iter));
    }
    try testing.expectEqual(@as(u32, 2), Iter.new(arr[0..]).nth(0).?.*);
    try testing.expectEqual(@as(u32, 3), Iter.new(arr[0..]).nth(1).?.*);
    try testing.expectEqual(@as(u32, 4), Iter.new(arr[0..]).nth(2).?.*);
    try testing.expectEqual(@as(?*u32, null), Iter.new(arr[0..]).nth(3));
    try testing.expectEqual(@as(?*u32, null), Iter.new(arr[0..]).nth(4));
}

fn DeriveFlatMap(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "flat_map")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn flat_map(self: Iter, f: anytype) iter.FlatMap(Iter, @TypeOf(f), iter.codomain(@TypeOf(f))) {
                const I = comptime iter.FlatMap(Iter, @TypeOf(f), iter.codomain(@TypeOf(f)));
                return I.new(self, f);
            }
        };
    }
}

test "derive flat_map" {
    var arr = [_]u32{ 2, 3, 4 };
    const Iter = MakeSliceIter(DeriveFlatMap, u32);
    var flat_map = Iter.new(arr[0..]).flat_map(struct {
        fn call(i: *u32) range.RangeIter(u32) {
            return range.range(@as(u32, 0), i.*, 1);
        }
    }.call);
    comptime {
        assert(isIterator(Iter));
        assert(isIterator(@TypeOf(flat_map)));
    }
    try testing.expectEqual(@as(?u32, 0), flat_map.next());
    try testing.expectEqual(@as(?u32, 1), flat_map.next());
    try testing.expectEqual(@as(?u32, 0), flat_map.next());
    try testing.expectEqual(@as(?u32, 1), flat_map.next());
    try testing.expectEqual(@as(?u32, 2), flat_map.next());
    try testing.expectEqual(@as(?u32, 0), flat_map.next());
    try testing.expectEqual(@as(?u32, 1), flat_map.next());
    try testing.expectEqual(@as(?u32, 2), flat_map.next());
    try testing.expectEqual(@as(?u32, 3), flat_map.next());
    try testing.expectEqual(@as(?u32, null), flat_map.next());
}

fn DerivePartialCmp(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "partial_cmp")) |_| {
        return struct {};
    } else if (meta.isPartialOrd(Iter.Item)) {
        return struct {
            pub fn partial_cmp(self: Iter, other: anytype) ?math.Order {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.PartialCmp(Iter.Item).partial_cmp(self, other);
            }
        };
    } else {
        return struct {};
    }
}

test "derive partial_cmp Int" {
    const Iter = range.MakeRangeIter(DerivePartialCmp, f64);
    const Order = math.Order;
    try testing.expectEqual(@as(?Order, .eq), Iter.new(@as(f64, 2), 11, 2).partial_cmp(Iter.new(@as(f64, 2), 11, 2)));
    try testing.expectEqual(@as(?Order, .eq), Iter.new(@as(f64, 2), 2, 2).partial_cmp(Iter.new(@as(f64, 2), 2, 2)));
    try testing.expectEqual(@as(?Order, .lt), Iter.new(@as(f64, 2), 11, 2).partial_cmp(Iter.new(@as(f64, 3), 11, 2)));
    try testing.expectEqual(@as(?Order, .gt), Iter.new(@as(f64, 2), 11, 2).partial_cmp(Iter.new(@as(f64, 2), 9, 2)));
}

test "derive partial_cmp Ptr" {
    const Iter = MakeSliceIter(DerivePartialCmp, f32);
    const Order = math.Order;
    {
        var arr1 = [_]f32{ 0.0, 1.1, 2.2, 3.3 };
        var arr2 = [_]f32{ 0.0, 1.1, 2.2, 3.3 };
        try testing.expectEqual(@as(?Order, .eq), Iter.new(arr1[0..]).partial_cmp(Iter.new(arr2[0..])));
        try testing.expectEqual(@as(?Order, .eq), Iter.new(arr1[0..0]).partial_cmp(Iter.new(arr2[0..0])));
        try testing.expectEqual(@as(?Order, .lt), Iter.new(arr1[0..2]).partial_cmp(Iter.new(arr2[0..3])));
        try testing.expectEqual(@as(?Order, .gt), Iter.new(arr1[0..3]).partial_cmp(Iter.new(arr2[0..2])));
    }
    {
        var arr1 = [_]f32{math.nan(f32)};
        var arr2 = [_]f32{};
        try testing.expectEqual(@as(?Order, .gt), Iter.new(arr1[0..]).partial_cmp(Iter.new(arr2[0..])));
    }
    {
        var arr1 = [_]f32{math.nan(f32)};
        var arr2 = [_]f32{math.nan(f32)};
        try testing.expectEqual(@as(?Order, null), Iter.new(arr1[0..]).partial_cmp(Iter.new(arr2[0..])));
    }
    {
        var arr1 = [_]f32{ 1.5, math.nan(f32) };
        var arr2 = [_]f32{ 1.5, math.nan(f32) };
        try testing.expectEqual(@as(?Order, null), Iter.new(arr1[0..]).partial_cmp(Iter.new(arr2[0..])));
    }
}

fn DeriveCmp(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "cmp")) |_| {
        return struct {};
    } else if (meta.isOrd(Iter.Item)) {
        return struct {
            pub fn cmp(self: Iter, other: anytype) math.Order {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other);
            }
        };
    } else {
        return struct {};
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
    } else if (meta.isOrd(Iter.Item)) {
        return struct {
            pub fn le(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.lte);
            }
        };
    } else {
        return struct {};
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
    } else if (meta.isOrd(Iter.Item)) {
        return struct {
            pub fn ge(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.gte);
            }
        };
    } else {
        return struct {};
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
    } else if (meta.isOrd(Iter.Item)) {
        return struct {
            pub fn lt(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.lt);
            }
        };
    } else {
        return struct {};
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
    } else if (meta.isOrd(Iter.Item)) {
        return struct {
            pub fn gt(self: Iter, other: anytype) bool {
                comptime assert(meta.isIterator(@TypeOf(other)));
                comptime assert(Iter.Item == @TypeOf(other).Item);
                return iter.Cmp(Iter.Item).cmp(self, other).compare(.gt);
            }
        };
    } else {
        return struct {};
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
    } else if (meta.isProduct(Iter.Item)) {
        return struct {
            pub fn product(self: Iter) meta.Product.Output(Iter.Item) {
                return meta.Product.product(self);
            }
        };
    } else {
        return struct {};
    }
}

test "derive product int" {
    const Iter = range.MakeRangeIter(DeriveProduct, u32);
    try testing.expectEqual(@as(u32, 3840), Iter.new(@as(u32, 2), 11, 2).product());
    try testing.expectEqual(@as(u32, 0), Iter.new(@as(u32, 0), 10, 1).product());
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
    } else if (meta.isSum(Iter.Item)) {
        return struct {
            pub fn sum(self: Iter) meta.Sum.Output(Iter.Item) {
                return meta.Sum.sum(self);
            }
        };
    } else {
        return struct {};
    }
}

test "derive sum int" {
    const Iter = range.MakeRangeIter(DeriveSum, u32);
    try testing.expectEqual(@as(u32, 0), Iter.new(@as(u32, 0), 0, 1).sum());
    try testing.expectEqual(@as(u32, 55), Iter.new(@as(u32, 0), 11, 1).sum());
}

test "derive sum ptr" {
    {
        var arr = [_]u32{ 1, 2, 3, 4, 5 };
        const Iter = MakeSliceIter(DeriveSum, u32);
        try testing.expectEqual(Iter.new(arr[0..0]).sum(), @as(u32, 0));
        try testing.expectEqual(Iter.new(arr[0..]).sum(), @as(u32, 15));
    }
    {
        const T = struct {
            val: u32,
            pub fn sum(it: anytype) meta.Sum.Output(@TypeOf(it).Item) {
                var jt = it;
                var acc: @This() = @This(){ .val = 0 };
                while (jt.next()) |t| {
                    if (t.val % 2 == 0)
                        acc.val += t.val;
                }
                return acc;
            }
        };
        var arr1 = [_]T{ T{ .val = 1 }, T{ .val = 2 }, T{ .val = 3 }, T{ .val = 4 } };
        const Iter = MakeSliceIter(DeriveSum, T);
        try testing.expectEqual(T{ .val = 6 }, Iter.new(arr1[0..]).sum());
    }
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
    } else if (meta.isOrd(Iter.Item)) {
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
                    if (meta.Ord.cmp(acc, val) == std.math.Order.lt) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    } else {
        return struct {};
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
            pub fn max_by(self: Iter, compare: fn (*const Iter.Item, *const Iter.Item) math.Order) ?Iter.Item {
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
    const max_by = Iter.new(@as(u32, 0), 10, 1).max_by(meta.Ord.on(*const u32));
    try testing.expectEqual(@as(?u32, 9), max_by);
}

test "derive max_by empty" {
    const Iter = range.MakeRangeIter(DeriveMaxBy, u32);
    const max_by = Iter.new(@as(u32, 0), 0, 1).max_by(struct {
        fn call(x: *const u32, y: *const u32) math.Order {
            return math.order(x.*, y.*);
        }
    }.call);
    try testing.expectEqual(@as(?u32, null), max_by);
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
                    if (meta.Ord.cmp(f(&acc), f(&val)) == .lt) {
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
    } else if (meta.isOrd(Iter.Item)) {
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
                    if (meta.Ord.cmp(acc, val) == math.Order.gt) {
                        acc = val;
                    }
                }
                return acc;
            }
        };
    } else {
        return struct {};
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
            pub fn min_by(self: Iter, compare: fn (*const Iter.Item, *const Iter.Item) math.Order) ?Iter.Item {
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
    const min_by = Iter.new(@as(u32, 0), 10, 1).min_by(meta.Ord.on(*const u32));
    try testing.expectEqual(@as(?u32, 0), min_by);
}

test "derive min_by empty" {
    const Iter = range.MakeRangeIter(DeriveMinBy, u32);
    const min_by = Iter.new(@as(u32, 0), 0, 1).min_by(struct {
        fn call(x: *const u32, y: *const u32) math.Order {
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
                    if (meta.Ord.cmp(f(&acc), f(&val)) == .gt) {
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

fn DeriveFlatten(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "flatten")) |_| {
        return struct {};
    } else if (meta.isIterator(Iter.Item)) {
        return struct {
            pub fn flatten(self: Iter) iter.Flatten(Iter) {
                return iter.Flatten(Iter).new(self);
            }
        };
    } else {
        return struct {};
    }
}

test "derive flatten" {
    const Gen = struct {
        fn call(x: u32) range.RangeIter(u32) {
            return range.range(@as(u32, 0), x, 1);
        }
    };
    var it = range.range(@as(u32, 1), 4, 1).map(Gen.call).flatten();

    // range(0, 1)
    try testing.expectEqual(@as(?u32, 0), it.next());
    // range(0, 2)
    try testing.expectEqual(@as(?u32, 0), it.next());
    try testing.expectEqual(@as(?u32, 1), it.next());
    // range(0, 3)
    try testing.expectEqual(@as(?u32, 0), it.next());
    try testing.expectEqual(@as(?u32, 1), it.next());
    try testing.expectEqual(@as(?u32, 2), it.next());
    try testing.expectEqual(@as(?u32, null), it.next());
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

fn DeriveTryFold(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "try_fold")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn try_fold(self: Iter, init: anytype, f: anytype) iter.codomain(@TypeOf(f)) {
                comptime {
                    const B = @TypeOf(init);
                    const F = @TypeOf(f);
                    const R = iter.codomain(F);
                    assert(iter.is_binary_func_type(F));
                    assert(std.meta.trait.is(.ErrorUnion)(R));
                    assert(F == fn (B, Iter.Item) iter.err_type(R)!B);
                }
                var it = self;
                var acc = init;
                while (it.next()) |value| {
                    acc = try f(acc, value);
                }
                return acc;
            }
        };
    }
}

test "derive try_fold" {
    {
        var arr = [_]u32{ 1, 2, 3, 4, 5 };
        const Iter = MakeSliceIter(DeriveTryFold, u32);
        try testing.expectEqual(@as(error{Overflow}!u32, 15), Iter.new(arr[0..]).try_fold(@as(u32, 0), struct {
            fn call(acc: u32, v: *u32) error{Overflow}!u32 {
                return math.add(u32, acc, v.*);
            }
        }.call));
    }
    {
        var arr = [_]u8{ 100, 150, 200 };
        const Iter = MakeSliceIter(DeriveTryFold, u8);
        const Result = error{Overflow}!u8;
        try testing.expectEqual(@as(Result, error.Overflow), Iter.new(arr[0..]).try_fold(@as(u8, 0), struct {
            fn call(acc: u8, v: *u8) Result {
                return math.add(u8, acc, v.*);
            }
        }.call));
    }
}

fn DeriveTryForeach(comptime Iter: type) type {
    comptime assert(isIterator(Iter));

    if (meta.have_fun(Iter, "try_for_each")) |_| {
        return struct {};
    } else {
        return struct {
            pub fn try_for_each(self: Iter, f: anytype) iter.codomain(@TypeOf(f)) {
                comptime {
                    const F = @TypeOf(f);
                    const R = iter.codomain(F);
                    assert(iter.is_unary_func_type(F));
                    assert(std.meta.trait.is(.ErrorUnion)(R));
                    assert(F == fn (Iter.Item) iter.err_type(R)!void);
                }
                var it = self;
                while (it.next()) |value| {
                    try f(value);
                }
            }
        };
    }
}

test "derive try_for_each" {
    try struct {
        var i: u32 = 0;
        fn call(x: *u32) !void {
            i += x.*;
        }
        fn dotest() !void {
            var arr = [_]u32{ 1, 2, 3, 4, 5 };
            const Iter = MakeSliceIter(DeriveTryForeach, u32);
            _ = try Iter.new(arr[0..]).try_for_each(call);
            try testing.expectEqual(@as(u32, 15), i);
        }
    }.dotest();
    try struct {
        var i: u8 = 0;
        fn call(x: *u8) !void {
            i = try math.add(u8, i, x.*);
        }
        fn dotest() !void {
            var arr = [_]u8{ 100, 150, 200 };
            const Iter = MakeSliceIter(DeriveTryForeach, u8);
            try testing.expectEqual(@as(anyerror!void, error.Overflow), Iter.new(arr[0..]).try_for_each(call));
        }
    }.dotest();
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
    var eiter = MakeSliceIter(DeriveIterator, u32).new(arr[0..]).enumerate().map(struct {
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
            pub fn map(self: Iter, f: anytype) iter.Map(Iter, @TypeOf(f)) {
                return iter.Map(Iter, @TypeOf(f)).new(f, self);
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

/// Derives default implementations of iterator functions
///
/// # Details
/// DeriveIterator takes a type `Iter` which must be an Iterator, derives default implementations of iterator functions.
/// The generated functions only depends on the `next` method of the `Iter` type.
/// If the type have any iterator functions itself yet, generating same name functions would be supressed.
///
pub fn DeriveIterator(comptime Iter: type) type {
    comptime assert(meta.isIterator(Iter));
    return struct {
        pub usingnamespace DerivePeekable(Iter);
        pub usingnamespace DerivePosition(Iter);
        pub usingnamespace DeriveCycle(Iter);
        pub usingnamespace DeriveCopied(Iter);
        pub usingnamespace DeriveCloned(Iter);
        pub usingnamespace DeriveNth(Iter);
        pub usingnamespace DeriveLast(Iter);
        pub usingnamespace DeriveFlatMap(Iter);
        pub usingnamespace DeriveFlatten(Iter);
        pub usingnamespace DerivePartialCmp(Iter);
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
        pub usingnamespace DeriveTryFold(Iter);
        pub usingnamespace DeriveTryForeach(Iter);
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
        pub usingnamespace DeriveZip(Iter);
    };
}

test "derive iterator" {
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
    const Iter = MakeSliceIter(DeriveIterator, u32);
    var mfm = Iter.new(arr[0..]).chain(Iter.new(arr2[0..]))
        .map(Triple.call_ref) // derive map for SliceIter
        .filter(IsEven.call) // more derive filter for Map
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

/// Derive `eq` of `PartialEq` for the type `T`
///
/// # Details
/// For type `T` which is struct or tagged union type, derive `eq` method.
/// The signature of that method should be `fn (self: *const T, other: *const T) bool`.
///
/// This function should be used like below:
/// ```zig
/// struct {
///   val1: type1, // must not be pointer type
///   val2: type2, // must not be pointer type
///   pub usingnamespace DerivePartialEq(@This());
/// }
/// ```
///
/// This definition declares the type have `eq` method same as below declaration:
/// ```zig
/// struct {
///   val1: type1,
///   val2: type2,
///   pub fn eq(self: *const @This(), other: *const @This()) bool {
///     if (!PartialEq.eq(&self.val1, &other.val1))
///       return false;
///     if (!PartialEq.eq(&self.val2, &other.val2))
///       return false;
///     return true;
///   }
/// }
/// ```
///
pub fn DerivePartialEq(comptime T: type) type {
    comptime assert(trait.is(.Struct)(T) or trait.is(.Union)(T));
    return struct {
        pub fn eq(self: *const T, other: *const T) bool {
            if (comptime trait.is(.Struct)(T)) {
                inline for (std.meta.fields(T)) |field| {
                    if (comptime trait.isSingleItemPtr(field.field_type))
                        @compileError("Cannot Derive PartialEq for " ++ @typeName(T) ++ "." ++ field.name ++ ":" ++ @typeName(field.field_type));
                    if (!PartialEq.eq(&@field(self, field.name), &@field(other, field.name)))
                        return false;
                }
                return true;
            }
            if (comptime trait.is(.Union)(T)) {
                if (@typeInfo(T).Union.tag_type == null)
                    @compileError("Cannot Derive PartialEq for untagged union type " ++ @typeName(T));

                const tag = @typeInfo(T).Union.tag_type.?;
                const self_tag = std.meta.activeTag(self.*);
                const other_tag = std.meta.activeTag(other.*);
                if (self_tag != other_tag) return false;

                inline for (std.meta.fields(T)) |field| {
                    if (comptime trait.isSingleItemPtr(field.field_type))
                        @compileError("Cannot Derive PartialEq for " ++ @typeName(T) ++ "." ++ field.name ++ ":" ++ @typeName(field.field_type));
                    if (@field(tag, field.name) == self_tag)
                        return PartialEq.eq(&@field(self, field.name), &@field(other, field.name));
                }
                return false;
            }
            @compileError("Cannot Derive PartialEq for type " ++ @typeName(T));
        }

        pub fn ne(self: *const T, other: *const T) bool {
            return !eq(self, other);
        }
    };
}

test "DerivePartialEq" {
    {
        const T = union(enum) {
            val: u32,
            // deriving `eq`
            pub usingnamespace DerivePartialEq(@This());
        };
        const x: T = T{ .val = 5 };
        const y: T = T{ .val = 5 };
        try testing.expect(PartialEq.eq(x, y));
    }
    {
        // contains pointer
        const T = struct {
            val: *u32,
            fn new(val: *u32) @This() {
                return .{ .val = val };
            }
            // pub usingnamespace DerivePartialEq(@This());
            // impl `eq` manually.
            // It is not allowed for deriving because pointer is included.
            pub fn eq(self: *const @This(), other: *const @This()) bool {
                return self.val.* == other.val.*;
            }
        };
        var v0 = @as(u32, 5);
        var v1 = @as(u32, 5);
        const x = T.new(&v0);
        const y = T.new(&v1);
        try testing.expect(PartialEq.eq(x, y));
    }
    {
        // tagged union
        const E = union(enum) {
            A,
            B,
            C,
            pub usingnamespace DerivePartialEq(@This());
        };
        // complex type
        const T = struct {
            val: ?(error{Err}![2]E),
            pub usingnamespace DerivePartialEq(@This());
        };
        try testing.expect(PartialEq.eq(T{ .val = null }, T{ .val = null }));
        try testing.expect(PartialEq.eq(T{ .val = error.Err }, T{ .val = error.Err }));
        try testing.expect(PartialEq.eq(T{ .val = [_]E{ .A, .B } }, T{ .val = [_]E{ .A, .B } }));
        try testing.expect(!PartialEq.eq(T{ .val = [_]E{ .A, .B } }, T{ .val = [_]E{ .A, .C } }));
        try testing.expect(!PartialEq.eq(T{ .val = [_]E{ .A, .B } }, T{ .val = error.Err }));
    }
}
