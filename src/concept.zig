const std = @import("std");

const tool = @import("./tool.zig");
const meta = @import("./meta.zig");

const trait = std.meta.trait;
const assert = std.debug.assert;
const testing = std.testing;

const deref_type = meta.deref_type;
const is_or_ptrto = meta.is_or_ptrto;

// iterator converters for unit tests
const to_iter = struct {
    const make = @import("./to_iter/make.zig");
    fn MakeSliceIter(comptime F: fn (type) type, comptime T: type) type {
        comptime return make.MakeSliceIter(F, T);
    }

    fn SliceIter(comptime Item: type) type {
        comptime return make.MakeSliceIter(tool.DeriveNothing, Item);
    }

    fn ArrayIter(comptime Item: type, comptime N: usize) type {
        comptime return make.MakeArrayIter(tool.DeriveNothing, Item, N);
    }
};

// range iterators for unit tests
const range = struct {
    const make = @import("./range/make.zig");
    fn MakeRange(comptime F: fn (type) type, comptime T: type) type {
        comptime return make.MakeRange(F, T);
    }

    fn Range(comptime T: type) type {
        comptime return make.MakeRange(tool.DeriveNothing, T);
    }

    fn range(start: anytype, end: @TypeOf(start)) Range(@TypeOf(start)) {
        return Range(@TypeOf(start)).new(start, end);
    }
};

fn implSum(comptime T: type) bool {
    comptime {
        if (trait.isNumber(T) or trait.is(.Vector)(T))
            return true;
        if (meta.have_fun(T, "sum")) |sum_ty| {
            const info = @typeInfo(sum_ty);
            // fn (?) ...
            if (info.Fn.args.len != 1)
                return false;
            // fn (anytype) ...
            if (!info.Fn.is_generic or info.Fn.args[0].arg_type != null)
                return false;

            // if (info.Fn.return_type) |_|
            //     return false;

            // Following constraints should be verified to be met if possible.
            // But this is not allowed by Zig 0.9.1 type system.
            //
            // ```
            // fn (iter: anytype) @TypeOf(iter).Item
            // where @TypeOf(iter).Item == T
            // ```
            //
            // However, when calling 'Sumable.sum', above constraints will be verified in type checking of it's declaration.
            // That signature is `fn (iter: anytype) @TypeOf(iter).Item`.
            //
            return true;

            // or

            // // A dummy iterator
            // // that `Item` equals to `T`.
            // const O: type = struct {
            //     pub const Self: type = @This();
            //     pub const Item: type = T;
            //     pub fn next(self: *Self) ?Item {
            //         _ = self;
            //         return null;
            //     }
            // };
            // // T.sum(O) evaluation involves performs a type check, type error can occur,
            // // resuling in compilation failure.
            // return @TypeOf(T.sum(O)) == fn (O) O.Item;
        }
        return false;
    }
}

pub fn isSum(comptime T: type) bool {
    comptime return is_or_ptrto(implSum)(T);
}

comptime {
    assert(isSum(u32));
    assert(isSum(f64));
    assert(isSum(*u32));
    assert(isSum(*const u32));
    assert(!isSum(**u32));
    assert(!isSum([]f64));
    assert(!isSum([*]const u8));
    assert(!isSum(to_iter.SliceIter(u64)));
    const T = struct {
        const T = @This();
        val: u32,
        // requires an Iterator that Item is equals to T.
        pub fn sum(iter: anytype) T {
            var acc = T{ .val = 0 };
            var it = iter;
            while (it.next()) |v| {
                acc.val += v.val;
            }
            return acc;
        }
    };
    assert(isSum(T));
    const U = struct {
        const U = @This();
        val: u32,
        pub fn sum(iter: range.MakeRange(tool.DeriveNothing, u32)) U {
            var acc = U{ .val = 0 };
            var it = iter;
            while (it.next()) |v| {
                acc.val += v;
            }
            return acc;
        }
    };
    assert(!isSum(U));
}

test "Sum" {
    const T = struct {
        const T = @This();
        val: u32,
        pub fn sum(iter: anytype) T {
            var acc: u32 = 0;
            var it = iter;
            while (it.next()) |v| {
                acc += v.val;
            }
            return T{ .val = acc };
        }
    };
    comptime assert(implSum(T));
}

pub const Sum = struct {
    pub fn Output(comptime T: type) type {
        comptime assert(isSum(T));
        return deref_type(T);
    }

    // summing up on primitive types or pointer types that points to primitive type
    fn sum_prim(iter: anytype) Output(@TypeOf(iter).Item) {
        const Iter = @TypeOf(iter);
        const T = deref_type(Iter.Item);
        var acc: T = 0;
        var it = iter;
        while (it.next()) |val| {
            acc += if (comptime trait.isSingleItemPtr(Iter.Item)) val.* else val;
        }
        return acc;
    }

    pub fn is_prim(comptime T: type) bool {
        return trait.isNumber(T) or trait.is(.Vector)(T);
    }

    /// Summation on an Iterator
    pub fn sum(iter: anytype) Output(@TypeOf(iter).Item) {
        const Iter = @TypeOf(iter);
        comptime assert(meta.isIterator(Iter));
        comptime assert(isSum(Iter.Item));

        if (comptime is_or_ptrto(is_prim)(Iter.Item))
            return sum_prim(iter);

        return deref_type(Iter.Item).sum(iter);
    }
};

comptime {
    var arr1 = [_]u32{};
    var arr2 = [_]i64{};
    const I = to_iter.SliceIter;
    assert(@TypeOf(Sum.sum(I(u32).new(arr1[0..]))) == u32);
    assert(@TypeOf(Sum.sum(I(i64).new(arr2[0..]))) == i64);
}

test "Sum" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const I = to_iter.SliceIter(u32);
    try testing.expectEqual(@as(u32, 0), Sum.sum(I.new(arr[0..0])));
    try testing.expectEqual(@as(u32, 15), Sum.sum(I.new(arr[0..5])));
    try testing.expectEqual(@as(u32, 36), Sum.sum(I.new(arr[0..8])));
    try testing.expectEqual(@as(u32, 55), Sum.sum(I.new(arr[0..])));
}

fn implProduct(comptime T: type) bool {
    comptime {
        if (trait.isNumber(T) or trait.is(.Vector)(T))
            return true;
        if (meta.have_fun(T, "product")) |product_ty| {
            const info = @typeInfo(product_ty);
            // fn (?) ...
            if (info.Fn.args.len != 1)
                return false;
            // fn (anytype) ...
            if (!info.Fn.is_generic or info.Fn.args[0].arg_type != null)
                return false;

            // if (info.Fn.return_type) |_|
            //     return false;

            // Following constraints should be verified to be met if possible.
            // But this is not allowed by Zig 0.9.1 type system.
            //
            // ```
            // fn (iter: anytype) @TypeOf(iter).Item
            // where @TypeOf(iter).Item == T
            // ```
            //
            // However, when calling 'Multiplyable.product', above constraints will be verified in type checking of it's declaration.
            // That signature is `fn (iter: anytype) @TypeOf(iter).Item`.
            //
            return true;

            // or

            // // A dummy iterator
            // // that `Item` equals to `T`.
            // const O: type = struct {
            //     pub const Self: type = @This();
            //     pub const Item: type = T;
            //     pub fn next(self: *Self) ?Item {
            //         _ = self;
            //         return null;
            //     }
            // };
            // // T.product(O) evaluation involves performs a type check, type error can occur,
            // // resuling in compilation failure.
            // return @TypeOf(T.product(O)) == fn (O) O.Item;
        }
        return false;
    }
}

pub fn isProduct(comptime T: type) bool {
    comptime return is_or_ptrto(implProduct)(T);
}

comptime {
    assert(isProduct(u32));
    assert(isProduct(f64));
    assert(!isProduct([]f64));
    assert(!isProduct([*]const u8));
    assert(!isProduct(to_iter.SliceIter(u64)));
    const T = struct {
        const T = @This();
        val: u32,
        // requires an Iterator that Item is equals to T.
        pub fn product(iter: anytype) T {
            var acc = T{ .val = 0 };
            var it = iter;
            while (it.next()) |v| {
                acc.val *= v.val;
            }
            return acc;
        }
    };
    assert(isProduct(T));
    const U = struct {
        const U = @This();
        val: u32,
        pub fn product(iter: range.MakeRange(tool.DeriveNothing, u32)) U {
            var acc = U{ .val = 0 };
            var it = iter;
            while (it.next()) |v| {
                acc.val *= v;
            }
            return acc;
        }
    };
    assert(!isProduct(U));
}

test "product" {
    const T = struct {
        const T = @This();
        val: u32,
        pub fn product(iter: anytype) T {
            var acc: u32 = 1;
            var it = iter;
            while (it.next()) |v| {
                acc *= v.val;
            }
            return T{ .val = acc };
        }
    };
    comptime assert(implProduct(T));
}

pub const Product = struct {
    pub fn Output(comptime T: type) type {
        comptime assert(isProduct(T));
        return deref_type(T);
    }

    // product on primitive types or pointer types that points to primitive type
    fn prod_prim(iter: anytype) Output(@TypeOf(iter).Item) {
        const Iter = @TypeOf(iter);
        const T = deref_type(Iter.Item);
        var acc: T = 1;
        var it = iter;
        while (it.next()) |val| {
            acc *= if (comptime trait.isSingleItemPtr(Iter.Item)) val.* else val;
        }
        return acc;
    }

    pub fn is_prim(comptime T: type) bool {
        return trait.isNumber(T) or trait.is(.Vector)(T);
    }

    pub fn product(iter: anytype) Output(@TypeOf(iter).Item) {
        const Iter = @TypeOf(iter);
        comptime assert(meta.isIterator(Iter));
        comptime assert(isProduct(Iter.Item));

        if (comptime is_or_ptrto(is_prim)(Iter.Item))
            return prod_prim(iter);

        return deref_type(Iter.Item).product(iter);
    }
};

comptime {
    var arr1 = [_]u32{};
    var arr2 = [_]i64{};
    const I = struct {
        fn call(comptime T: type) type {
            return to_iter.SliceIter(T);
        }
    }.call;
    assert(@TypeOf(Product.product(I(u32).new(arr1[0..]))) == u32);
    assert(@TypeOf(Product.product(I(i64).new(arr2[0..]))) == i64);
}

test "Product" {
    var arr = [_]u32{ 1, 1, 2, 3, 5, 8, 13, 21, 34 };
    const I = to_iter.SliceIter(u32);
    try testing.expectEqual(@as(u32, 1), Product.product(I.new(arr[5..5])));
    try testing.expectEqual(@as(u32, 6), Product.product(I.new(arr[0..4])));
    try testing.expectEqual(@as(u32, 104), Product.product(I.new(arr[5..7])));
}
