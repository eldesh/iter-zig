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
        // for avoiding dependency loop,
        // delay evaluation such like `(() -> e)()`
        var M = struct {
            pub const N = struct {
                pub fn map(self: Iter, f: anytype) iter.IterMap(Iter, @TypeOf(f)) {
                    return iter.IterMap(Iter, @TypeOf(f)).new(f, self);
                }
            };
        };
        return M.N;
    }
}

pub fn Derive(comptime Iter: type) type {
    return DeriveMap(Iter);
}

test "derive map" {
    const Double = struct {
        pub fn apply(x: u32) u32 {
            return x * 2;
        }
    };

    var arr = [_]u32{ 1, 2, 3 };
    const Iter = MakeSliceIter(DeriveMap, u32);
    var map = MakeSliceIter(DeriveMap, u32).new(arr[0..]).map(Double.apply);
    comptime {
        assert(meta.isIterator(Iter));
        assert(meta.isIterator(@TypeOf(map)));
    }
    try testing.expect(map.next().? == 2);
    try testing.expect(map.next().? == 4);
    try testing.expect(map.next().? == 6);
    try testing.expect(map.next() == null);
}
