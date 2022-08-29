const std = @import("std");
pub usingnamespace @import("basis_concept");

const range = @import("./range.zig");

const SliceIter = @import("./to_iter.zig").SliceIter;
const ArrayIter = @import("./to_iter.zig").ArrayIter;
const ArrayListIter = @import("./to_iter.zig").ArrayListIter;
const SinglyLinkedListIter = @import("./to_iter.zig").SinglyLinkedListIter;
const Range = range.Range;

const math = std.math;
const trait = std.meta.trait;
const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

/// Compare std tuple types rather than values
///
/// # Details
/// Compare arity and field types each other.
/// The `==` operator can not comparing std tuples correctly.
/// Then the below expression evaluated always to false.
/// ```
/// std.meta.Tuple(&[_]type{u32}) == std.meta.Tuple(&[_]type{u32})
/// ```
pub fn eqTupleType(comptime exp: type, comptime act: type) bool {
    comptime {
        if (!std.meta.trait.isTuple(exp))
            return false;
        if (!std.meta.trait.isTuple(act))
            return false;

        const expfs = std.meta.fields(exp);
        const actfs = std.meta.fields(act);
        if (expfs.len != actfs.len) // compare arity
            return false;

        inline for (expfs) |expf, i| {
            if (expf.field_type != actfs[i].field_type)
                return false;
        }
        return true;
    }
}

comptime {
    assert(eqTupleType(std.meta.Tuple(&[_]type{u32}), std.meta.Tuple(&[_]type{u32})));
    assert(!eqTupleType(std.meta.Tuple(&[_]type{ u32, u32 }), std.meta.Tuple(&[_]type{u32})));
    assert(eqTupleType(std.meta.Tuple(&[_]type{ u32, i64 }), std.meta.Tuple(&[_]type{ u32, i64 })));
    assert(!eqTupleType(std.meta.Tuple(&[_]type{}), std.meta.Tuple(&[_]type{ u32, i64 })));
}

pub fn assertEqualTupleType(comptime x: type, comptime y: type) void {
    comptime assert(eqTupleType(x, y));
}

pub fn is_or_ptrto(comptime F: fn (type) bool) fn (type) bool {
    comptime {
        return struct {
            fn pred(comptime U: type) bool {
                if (F(U))
                    return true;
                return trait.isSingleItemPtr(U) and F(std.meta.Child(U));
            }
        }.pred;
    }
}

comptime {
    const isU32 = struct {
        fn call(comptime T: type) bool {
            return T == u32;
        }
    }.call;
    assert(is_or_ptrto(isU32)(u32));
    assert(!is_or_ptrto(isU32)(u16));
    assert(is_or_ptrto(isU32)(*u32));
    assert(!is_or_ptrto(isU32)(**u32));
}

pub fn deref_type(comptime T: type) type {
    if (trait.isSingleItemPtr(T)) {
        return std.meta.Child(T);
    } else {
        return T;
    }
}

comptime {
    assert(deref_type(u32) == u32);
    assert(deref_type(*u32) == u32);
    assert(deref_type(**u32) == *u32);
    assert(deref_type([]u8) == []u8);
    const U = union(enum) { Tag1, Tag2 };
    assert(deref_type(U) == U);
    assert(deref_type(*U) == U);
}

pub fn remove_pointer(comptime T: type) type {
    comptime assert(trait.isSingleItemPtr(T));
    return std.meta.Child(T);
}

pub fn remove_const_pointer(comptime T: type) type {
    comptime assert(trait.isSingleItemPtr(T) and trait.isConstPtr(T));
    var info = @typeInfo(T);
    info.Pointer.is_const = false;
    return remove_pointer(@Type(info));
}

comptime {
    assert(remove_pointer(*const u32) == u32);
    assert(remove_pointer(*[]const u8) == []const u8);
    assert(remove_const_pointer(*const u32) == u32);
    assert(remove_const_pointer(*const []u8) == []u8);
}

pub fn have_type(comptime T: type, name: []const u8) ?type {
    comptime {
        if (!trait.isContainer(T))
            return null;
        if (!@hasDecl(T, name))
            return null;

        const field = @field(T, name);
        if (@typeInfo(@TypeOf(field)) == .Type) {
            return field;
        }
        return null;
    }
}

comptime {
    const E = struct {};
    const C = struct {
        pub const Self = @This();
    };
    assert(have_type(E, "Self") == null);
    assert(have_type(C, "Self") != null);
    assert(have_type(u32, "cmp") == null);
}

pub fn have_field(comptime T: type, name: []const u8) ?type {
    const fields = switch (@typeInfo(T)) {
        .Struct => |s| s.fields,
        .Union => |u| u.fields,
        .Enum => |e| e.fields,
        else => false,
    };

    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            return field.field_type;
        }
    }

    return null;
}

pub fn have_fun(comptime T: type, name: []const u8) ?type {
    comptime {
        if (!std.meta.trait.isContainer(T))
            return null;
        if (!@hasDecl(T, name))
            return null;
        return @TypeOf(@field(T, name));
    }
}

/// Check that the type `T` is an Iterator
pub fn isIterator(comptime T: type) bool {
    if (have_type(T, "Self")) |Self| {
        if (have_type(T, "Item")) |Item| {
            if (have_fun(T, "next")) |next_ty| {
                return next_ty == fn (*Self) ?Item;
            }
        }
    }
    return false;
}

comptime {
    assert(!isIterator(u32));
    assert(!isIterator([]const u8));
    assert(!isIterator([5]u64));
    assert(isIterator(ArrayIter(u32, 3)));
    assert(isIterator(SliceIter(u32)));
    assert(isIterator(ArrayListIter(u32)));
    assert(isIterator(SinglyLinkedListIter(u32)));
}

pub fn implSum(comptime T: type) bool {
    comptime {
        if (trait.isNumber(T) or trait.is(.Vector)(T))
            return true;
        if (have_fun(T, "sum")) |sum_ty| {
            const info = @typeInfo(sum_ty);
            // fn (?) ...
            if (info.Fn.args.len != 1)
                return false;
            // fn (anytype) ...
            if (!info.Fn.is_generic or info.Fn.args[0].arg_type != null)
                return false;

            if (info.Fn.return_type != null)
                return false;

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
    assert(!isSum([]f64));
    assert(!isSum([*]const u8));
    assert(!isSum(SliceIter(u64)));
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
        pub fn sum(iter: Range(u32)) U {
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
    var arr = [_]T{ .{ .val = 1 }, .{ .val = 2 }, .{ .val = 3 }, .{ .val = 4 } };
    const sum = T.sum(SliceIter(T).new(arr[0..]).map(struct {
        fn call(x: *const T) T {
            return x.*;
        }
    }.call));
    try testing.expectEqual(T{ .val = 10 }, sum);
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
        comptime assert(isIterator(Iter));
        comptime assert(isSum(Iter.Item));

        if (comptime is_or_ptrto(is_prim)(Iter.Item))
            return sum_prim(iter);

        return deref_type(Iter.Item).sum(iter);
    }
};

comptime {
    var arr1 = [_]u32{};
    var arr2 = [_]i64{};
    const I = SliceIter;
    assert(@TypeOf(Sum.sum(I(u32).new(arr1[0..]))) == u32);
    assert(@TypeOf(Sum.sum(I(i64).new(arr2[0..]))) == i64);
}

test "Sum" {
    var arr = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const I = SliceIter(u32);
    try testing.expectEqual(@as(u32, 0), Sum.sum(I.new(arr[0..0])));
    try testing.expectEqual(@as(u32, 15), Sum.sum(I.new(arr[0..5])));
    try testing.expectEqual(@as(u32, 36), Sum.sum(I.new(arr[0..8])));
    try testing.expectEqual(@as(u32, 55), Sum.sum(I.new(arr[0..])));
}

pub fn implProduct(comptime T: type) bool {
    comptime {
        if (trait.isNumber(T) or trait.is(.Vector)(T))
            return true;
        if (have_fun(T, "product")) |product_ty| {
            const info = @typeInfo(product_ty);
            // fn (?) ...
            if (info.Fn.args.len != 1)
                return false;
            // fn (anytype) ...
            if (!info.Fn.is_generic or info.Fn.args[0].arg_type != null)
                return false;

            if (info.Fn.return_type != null)
                return false;

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
    assert(!isProduct(SliceIter(u64)));
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
        pub fn product(iter: Range(u32)) U {
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
    var arr = [_]T{ .{ .val = 1 }, .{ .val = 2 }, .{ .val = 3 }, .{ .val = 4 } };
    const product = T.product(SliceIter(T).new(arr[0..]).map(struct {
        fn call(x: *const T) T {
            return x.*;
        }
    }.call));
    try testing.expectEqual(T{ .val = 24 }, product);
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
        comptime assert(isIterator(Iter));
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
            return SliceIter(T);
        }
    }.call;
    assert(@TypeOf(Product.product(I(u32).new(arr1[0..]))) == u32);
    assert(@TypeOf(Product.product(I(i64).new(arr2[0..]))) == i64);
}

test "Product" {
    var arr = [_]u32{ 1, 1, 2, 3, 5, 8, 13, 21, 34 };
    const I = SliceIter(u32);
    try testing.expectEqual(@as(u32, 1), Product.product(I.new(arr[5..5])));
    try testing.expectEqual(@as(u32, 6), Product.product(I.new(arr[0..4])));
    try testing.expectEqual(@as(u32, 104), Product.product(I.new(arr[5..7])));
}
