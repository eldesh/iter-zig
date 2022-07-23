const std = @import("std");

const range = @import("./range.zig");

const SliceIter = @import("./to_iter.zig").SliceIter;
const ArrayIter = @import("./to_iter.zig").ArrayIter;
const ArrayListIter = @import("./to_iter.zig").ArrayListIter;
const SinglyLinkedListIter = @import("./to_iter.zig").SinglyLinkedListIter;
const Range = range.RangeIter;

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
pub fn equalTuple(comptime exp: type, comptime act: type) bool {
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
    assert(equalTuple(std.meta.Tuple(&[_]type{u32}), std.meta.Tuple(&[_]type{u32})));
    assert(!equalTuple(std.meta.Tuple(&[_]type{ u32, u32 }), std.meta.Tuple(&[_]type{u32})));
    assert(equalTuple(std.meta.Tuple(&[_]type{ u32, i64 }), std.meta.Tuple(&[_]type{ u32, i64 })));
    assert(!equalTuple(std.meta.Tuple(&[_]type{}), std.meta.Tuple(&[_]type{ u32, i64 })));
}

pub fn assertEqualTuple(comptime x: type, comptime y: type) void {
    comptime assert(equalTuple(x, y));
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
    const decls = switch (@typeInfo(T)) {
        .Struct => |s| s.decls,
        .Union => |u| u.decls,
        .Enum => |e| e.decls,
        else => return null,
    };

    inline for (decls) |decl| {
        if (!decl.is_pub)
            continue;
        if (std.mem.eql(u8, decl.name, name)) {
            switch (decl.data) {
                .Fn => |fndecl| return fndecl.fn_type,
                else => break,
            }
        }
    }

    return null;
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

pub fn isCopyable(comptime T: type) bool {
    comptime {
        if (trait.is(.Void)(T))
            return true;
        if (trait.is(.Bool)(T) or trait.is(.Null)(T))
            return true;
        if (trait.isNumber(T))
            return true;
        if (trait.is(.Vector)(T) or trait.is(.Array)(T) or trait.is(.Optional)(T))
            return isCopyable(std.meta.Child(T));
        if (trait.is(.Fn)(T))
            return true;
        if (trait.is(.Enum)(T))
            return isCopyable(@typeInfo(T).Enum.tag_type);
        if (trait.is(.EnumLiteral)(T))
            return true;
        if (trait.is(.ErrorSet)(T))
            return true;
        if (trait.is(.ErrorUnion)(T))
            return isCopyable(@typeInfo(T).ErrorUnion.error_set) and isCopyable(@typeInfo(T).ErrorUnion.payload);
        if (trait.is(.Struct)(T) or trait.is(.Union)(T)) {
            if (trait.is(.Union)(T)) {
                if (@typeInfo(T).Union.tag_type) |tag| {
                    if (!isCopyable(tag))
                        return false;
                }
            }
            inline for (std.meta.fields(T)) |field| {
                if (!isCopyable(field.field_type))
                    return false;
            }
            // all type of fields are copyable
            return true;
        }
        return false;
    }
}

comptime {
    assert(isCopyable(u32));
    assert(isCopyable(struct { val: u32 }));
    assert(isCopyable(f64));
    assert(!isCopyable(*u64));
    assert(isCopyable(?f64));
    assert(isCopyable(struct { val: f32 }));
    assert(!isCopyable([]const u8));
    assert(!isCopyable([*]f64));
    assert(isCopyable([5]u32));
    const U = union(enum) { Tag1, Tag2, Tag3 };
    assert(isCopyable(U));
    assert(!isCopyable(*U));
    assert(!isCopyable(*const U));
    const OverflowError = error{Overflow};
    assert(isCopyable(@TypeOf(.Overflow))); // EnumLiteral
    assert(isCopyable(OverflowError)); // ErrorSet
    assert(isCopyable(OverflowError![2]U)); // ErrorUnion
    assert(isCopyable(?(error{Overflow}![2]U)));
    assert(isCopyable(struct { val: ?(error{Overflow}![2]U) }));
    assert(!isCopyable(struct { val: ?(error{Overflow}![2]*const U) }));
}

fn isClonableType(comptime T: type) bool {
    comptime {
        if (isCopyable(T))
            return true;

        if (have_type(T, "Self")) |Self| {
            if (have_type(T, "CloneError")) |CloneError| {
                if (have_fun(T, "clone")) |clone_ty| {
                    if (clone_ty == fn (Self) CloneError!Self)
                        return true;
                }
            }
        }
        return false;
    }
}

pub fn isClonable(comptime T: type) bool {
    comptime {
        if (isClonableType(T))
            return true;
        if (trait.isSingleItemPtr(T) and isClonableType(std.meta.Child(T)))
            return true;
        return false;
    }
}

comptime {
    assert(isClonable(u32));
    assert(isClonable(f64));
    assert(isClonable(*u32));
    assert(isClonable([16]u32));
    assert(!isClonable([]u32));
    const T = struct {
        pub const Self: type = @This();
        pub const CloneError: type = error{CloneError};
        x: u32,
        pub fn clone(self: Self) CloneError!Self {
            return .{ .x = self.x };
        }
    };
    assert(isClonable(T));
    assert(isClonable([2]T));
    assert(!isClonable([]const T));
    assert(isClonable(*T));
    assert(!isClonable([*]const T));
    assert(isClonable(struct { val: [2]T }));
    assert(isClonable(*struct { val: [2]T }));
}

pub const Clonable = struct {
    pub fn ResultType(comptime T: type) type {
        comptime assert(isClonable(T));
        const Out = if (trait.isSingleItemPtr(T)) std.meta.Child(T) else T;
        const Err = have_type(T, "CloneError") orelse error{};
        return Err!Out;
    }

    pub fn clone(value: anytype) ResultType(@TypeOf(value)) {
        const T = @TypeOf(value);
        comptime assert(isClonable(T));

        if (comptime isCopyable(T))
            return value;

        if (comptime trait.isSingleItemPtr(T)) {
            if (comptime isCopyable(std.meta.Child(T)))
                return value.*;
        }
        return value.clone();
    }
};

test "Clone" {
    const clone = Clonable.clone;
    try testing.expectEqual(@as(error{}!u32, 5), clone(@as(u32, 5)));
    try testing.expectEqual(@as(error{}!comptime_int, 5), clone(5));
    try testing.expectEqual(@as(error{}![3]u32, [_]u32{ 1, 2, 3 }), clone([_]u32{ 1, 2, 3 }));
    const val: u64 = 42;
    const ptr = &val;
    try testing.expectEqual(@as(error{}!u64, ptr.*), clone(ptr));

    var seq = range.range(@as(u32, 0), 5, 1);
    // consume head of 3elems
    try testing.expectEqual(@as(u32, 0), seq.next().?);
    try testing.expectEqual(@as(u32, 1), seq.next().?);
    try testing.expectEqual(@as(u32, 2), seq.next().?);
    // branch from the sequence
    var seq2 = Clonable.clone(seq) catch unreachable;
    try testing.expectEqual(@as(u32, 3), seq2.next().?);
    try testing.expectEqual(@as(u32, 4), seq2.next().?);
    try testing.expectEqual(@as(?u32, null), seq2.next());
    // resume seq
    try testing.expectEqual(@as(u32, 3), seq.next().?);
    try testing.expectEqual(@as(u32, 4), seq.next().?);
    try testing.expectEqual(@as(?u32, null), seq.next());

    const T = struct {
        pub const Self: type = @This();
        pub const CloneError: type = std.mem.Allocator.Error;
        ss: []u8,
        pub fn new(ss: []u8) Self {
            return .{ .ss = ss };
        }
        pub fn clone(self: Self) CloneError!Self {
            var ss = try testing.allocator.dupe(u8, self.ss);
            return Self{ .ss = ss };
        }
        pub fn destroy(self: *Self) void {
            testing.allocator.free(self.ss);
            self.ss.len = 0;
        }
    };

    var orig = T.new(try testing.allocator.dupe(u8, "foo"));
    defer orig.destroy();
    var new = clone(orig);
    defer if (new) |*obj| obj.destroy() else |_| {};
    try testing.expect(std.mem.eql(u8, orig.ss, (try new).ss));
}

fn isOrdType(comptime T: type) bool {
    comptime {
        // requires PartialOrd
        if (!isPartialOrdType(T))
            return false;
        // primitive type
        if (trait.isIntegral(T))
            return true;
        if (trait.is(.Vector)(T) and trait.isIntegral(std.meta.Child(T)))
            return true;
        // complex type impl 'cmp' method
        if (have_fun(T, "cmp")) |ty| {
            if (ty == fn (*const T, *const T) std.math.Order)
                return true;
        }
        return false;
    }
}

// TODO: to be comparable tuple
// TODO: to be comparable optional
pub fn isOrd(comptime T: type) bool {
    comptime {
        // comparable type or ..
        if (isOrdType(T))
            return true;
        // a pointer type that points to comparable type
        if (trait.isSingleItemPtr(T) and isOrdType(std.meta.Child(T)))
            return true;
        return false;
    }
}

comptime {
    assert(isOrd(u32));
    assert(isOrd(*u32));
    assert(!isOrd([]u32));
    assert(!isOrd([*]u32));
    assert(isOrd(i64));
    assert(isOrd(*const i64));
    assert(!isOrd(*[]const i64));
    assert(!isOrd([8]u64));
    assert(!isOrd(f64));
    assert(!isOrd(f32));
    const C = struct {
        val: u32,
        pub fn partial_cmp(x: *const @This(), y: *const @This()) ?std.math.Order {
            _ = x;
            _ = y;
            return null;
        }
        pub fn cmp(x: *const @This(), y: *const @This()) std.math.Order {
            _ = x;
            _ = y;
            return .lt;
        }
    };
    assert(isOrd(C));
    assert(isOrd(*C));
    const D = struct {
        val: u32,
        pub fn cmp(x: @This(), y: @This()) std.math.Order {
            _ = x;
            _ = y;
            return .lt;
        }
    };
    assert(!isOrd(D)); // partial_cmp is not implemented
    assert(!isOrd(*D));
}

pub const Ord = struct {
    /// General comparing function
    ///
    /// # Details
    /// Compares `Ord` values.
    /// If the type of `x` is a primitive type, `cmp` would be used like `cmp(5, 6)`.
    /// And for others, like `cmp(&x, &y)` where the typeof x is comparable.
    pub fn cmp(x: anytype, y: @TypeOf(x)) std.math.Order {
        const T = @TypeOf(x);
        comptime assert(isOrd(T));

        // primitive types
        if (comptime trait.isIntegral(T) or trait.is(.Vector)(T))
            return std.math.order(x, y);
        // pointer that points to
        if (comptime trait.isSingleItemPtr(T)) {
            const E = std.meta.Child(T);
            // primitive types
            if (comptime trait.isIntegral(E) or trait.is(.Vector)(E))
                return std.math.order(x.*, y.*);
        }
        // - composed type implements 'cmp' or
        // - pointer that points to 'cmp'able type
        return x.cmp(y);
    }

    /// Acquire the specilized 'cmp' function with 'T'.
    ///
    /// # Details
    /// The type of 'cmp' is evaluated as `fn (anytype,anytype) anytype` by default.
    /// To using the function specialized to a type, pass the function like `set(T)`.
    pub fn on(comptime T: type) fn (T, T) std.math.Order {
        return struct {
            fn call(x: T, y: T) std.math.Order {
                return cmp(x, y);
            }
        }.call;
    }
};

comptime {
    const zero = @as(u32, 0);
    var pzero = &zero;
    const one = @as(u32, 1);
    var pone = &one;
    assert(Ord.on(u32)(0, 1) == .lt);
    assert(Ord.on(*const u32)(pzero, pone) == .lt);
}

fn isPartialOrdType(comptime T: type) bool {
    comptime {
        // primitive type
        if (trait.isNumber(T))
            return true;
        if (trait.is(.Vector)(T) and trait.isNumber(std.meta.Child(T)))
            return true;
        // complex type impl 'partial_cmp' method
        if (have_fun(T, "partial_cmp")) |ty| {
            if (ty == fn (*const T, *const T) ?std.math.Order)
                return true;
        }
        return false;
    }
}

pub fn isPartialOrd(comptime T: type) bool {
    comptime {
        // comparable type or ..
        if (isPartialOrdType(T))
            return true;
        // a pointer type that points to comparable type
        if (trait.isSingleItemPtr(T) and isPartialOrdType(std.meta.Child(T)))
            return true;
        return false;
    }
}

comptime {
    assert(isPartialOrd(u32));
    assert(isPartialOrd(*const u64));
    assert(isPartialOrd(i64));
    assert(isPartialOrd(*const i64));
    assert(!isPartialOrd(*[]const i64));
    assert(!isPartialOrd([8]u64));
    assert(isPartialOrd(f64));
    const C = struct {
        pub fn partial_cmp(x: *const @This(), y: *const @This()) ?std.math.Order {
            _ = x;
            _ = y;
            return null;
        }
    };
    assert(isPartialOrd(C));
    assert(isPartialOrd(*C));
    const D = struct {
        pub fn partial_cmp(x: @This(), y: @This()) ?std.math.Order {
            _ = x;
            _ = y;
            return null;
        }
    };
    assert(!isPartialOrd(D));
    assert(!isPartialOrd(*D));
}

pub const PartialOrd = struct {
    fn partial_cmp_float(x: anytype, y: @TypeOf(x)) ?math.Order {
        comptime assert(trait.isFloat(@TypeOf(x)));
        if (math.isNan(x) or math.isNan(y))
            return null;
        return std.math.order(x, y);
    }

    pub fn partial_cmp(x: anytype, y: @TypeOf(x)) ?std.math.Order {
        const T = @TypeOf(x);
        comptime assert(isPartialOrd(T));

        // primitive types
        if (comptime trait.isFloat(T))
            return partial_cmp_float(x, y);
        if (comptime trait.isNumber(T))
            return math.order(x, y);

        // pointer that points to
        if (comptime trait.isSingleItemPtr(T)) {
            const E = std.meta.Child(T);
            comptime assert(isPartialOrdType(E));
            // primitive types
            if (comptime trait.isFloat(E))
                return partial_cmp_float(x.*, y.*);
            if (comptime trait.isNumber(E))
                return math.order(x.*, y.*);
        }
        // - composed type implements 'partial_cmp' or
        // - pointer that points to 'partial_cmp'able type
        return x.partial_cmp(y);
    }

    /// Acquire the specilized 'partial_cmp' function with 'T'.
    ///
    /// # Details
    /// The type of 'partial_cmp' is evaluated as `fn (anytype,anytype) anytype` by default.
    /// To using the function specialized to a type, pass the function like `with(T)`.
    pub fn on(comptime T: type) fn (T, T) ?std.math.Order {
        return struct {
            fn call(x: T, y: T) ?std.math.Order {
                return partial_cmp(x, y);
            }
        }.call;
    }
};

comptime {
    const x = @as(f32, 0.5);
    var px = &x;
    const y = @as(f32, 1.1);
    var py = &y;
    assert(PartialOrd.on(f32)(x, y).? == .lt);
    assert(PartialOrd.on(*const f32)(px, py).? == .lt);
    assert(PartialOrd.on(f32)(x, math.nan(f32)) == null);
    assert(PartialOrd.on(*const f32)(px, &math.nan(f32)) == null);
}

pub fn isSumableType(comptime T: type) bool {
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

pub fn isSumable(comptime T: type) bool {
    comptime {
        if (isSumableType(T))
            return true;
        if (trait.isSingleItemPtr(T) and isSumableType(std.meta.Child(T)))
            return true;
        return false;
    }
}

comptime {
    assert(isSumable(u32));
    assert(isSumable(f64));
    assert(!isSumable([]f64));
    assert(!isSumable([*]const u8));
    assert(!isSumable(SliceIter(u64)));
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
    assert(isSumable(T));
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
    assert(!isSumable(U));
}

test "sum" {
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
    comptime assert(isSumable(T));
    var arr = [_]T{ .{ .val = 1 }, .{ .val = 2 }, .{ .val = 3 }, .{ .val = 4 } };
    const sum = T.sum(SliceIter(T).new(arr[0..]).map(struct {
        fn call(x: *const T) T {
            return x.*;
        }
    }.call));
    try testing.expectEqual(T{ .val = 10 }, sum);
}

pub const Sumable = struct {
    pub fn Output(comptime T: type) type {
        comptime assert(isSumable(T));
        return if (trait.isSingleItemPtr(T)) remove_pointer(T) else T;
    }

    // summing up on primitive types or pointer types that points to primitive type
    fn sum_prim(iter: anytype) Output(@TypeOf(iter).Item) {
        const Iter = @TypeOf(iter);
        const is_ptr = comptime trait.isSingleItemPtr(Iter.Item);
        const T = if (is_ptr) std.meta.Child(Iter.Item) else Iter.Item;
        var acc: T = 0;
        var it = iter;
        while (it.next()) |val| {
            acc += if (comptime is_ptr) val.* else val;
        }
        return acc;
    }

    pub fn sum(iter: anytype) Output(@TypeOf(iter).Item) {
        const Item = @TypeOf(iter).Item;

        comptime assert(isSumable(Item));
        if (comptime trait.isNumber(Item) or trait.is(.Vector)(Item))
            return sum_prim(iter);

        if (comptime trait.isSingleItemPtr(Item)) {
            const E = std.meta.Child(Item);
            return if (comptime trait.isNumber(E) or trait.is(.Vector)(E))
                sum_prim(iter)
            else
                E.sum(iter);
        }

        return Item.sum(iter);
    }
};

pub fn isMultiplyableType(comptime T: type) bool {
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

pub fn isMultiplyable(comptime T: type) bool {
    comptime {
        if (isMultiplyableType(T))
            return true;
        if (trait.isSingleItemPtr(T) and isMultiplyableType(std.meta.Child(T)))
            return true;
        return false;
    }
}

comptime {
    assert(isMultiplyable(u32));
    assert(isMultiplyable(f64));
    assert(!isMultiplyable([]f64));
    assert(!isMultiplyable([*]const u8));
    assert(!isMultiplyable(SliceIter(u64)));
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
    assert(isMultiplyable(T));
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
    assert(!isMultiplyable(U));
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
    comptime assert(isMultiplyable(T));
    var arr = [_]T{ .{ .val = 1 }, .{ .val = 2 }, .{ .val = 3 }, .{ .val = 4 } };
    const product = T.product(SliceIter(T).new(arr[0..]).map(struct {
        fn call(x: *const T) T {
            return x.*;
        }
    }.call));
    try testing.expectEqual(T{ .val = 24 }, product);
}

pub const Multiplyable = struct {
    pub fn Output(comptime T: type) type {
        comptime assert(isMultiplyable(T));
        return if (trait.isSingleItemPtr(T)) remove_pointer(T) else T;
    }

    // product on primitive types or pointer types that points to primitive type
    fn prod_prim(iter: anytype) Output(@TypeOf(iter).Item) {
        const Iter = @TypeOf(iter);
        const is_ptr = comptime trait.isSingleItemPtr(Iter.Item);
        const T = if (is_ptr) std.meta.Child(Iter.Item) else Iter.Item;
        var acc: T = 1;
        var it = iter;
        while (it.next()) |val| {
            acc *= if (comptime is_ptr) val.* else val;
        }
        return acc;
    }

    pub fn product(iter: anytype) Output(@TypeOf(iter).Item) {
        const Item = @TypeOf(iter).Item;

        comptime assert(isMultiplyable(Item));
        if (comptime trait.isNumber(Item) or trait.is(.Vector)(Item))
            return prod_prim(iter);

        if (comptime trait.isSingleItemPtr(Item)) {
            const E = std.meta.Child(Item);
            return if (comptime trait.isNumber(E) or trait.is(.Vector)(E))
                prod_prim(iter)
            else
                E.product(iter);
        }

        return Item.product(iter);
    }
};
