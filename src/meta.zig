const std = @import("std");

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
    assert(is_or_ptrto(implClone)(u32));
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

/// Checks that the type `T` is `traivially copyable`.
///
/// # Details
/// Values of that types are able to be duplicated with just copying the binary sequence.
pub fn implCopy(comptime T: type) bool {
    comptime {
        if (trait.is(.Void)(T))
            return true;
        if (trait.is(.Bool)(T) or trait.is(.Null)(T))
            return true;
        if (trait.isNumber(T))
            return true;
        if (trait.is(.Vector)(T) or trait.is(.Array)(T) or trait.is(.Optional)(T))
            return implCopy(std.meta.Child(T));
        if (trait.is(.Fn)(T))
            return true;
        if (trait.is(.Enum)(T))
            return implCopy(@typeInfo(T).Enum.tag_type);
        if (trait.is(.EnumLiteral)(T))
            return true;
        if (trait.is(.ErrorSet)(T))
            return true;
        if (trait.is(.ErrorUnion)(T))
            return implCopy(@typeInfo(T).ErrorUnion.error_set) and implCopy(@typeInfo(T).ErrorUnion.payload);
        if (trait.is(.Struct)(T) or trait.is(.Union)(T)) {
            if (trait.is(.Union)(T)) {
                if (@typeInfo(T).Union.tag_type) |tag| {
                    if (!implCopy(tag))
                        return false;
                }
            }
            inline for (std.meta.fields(T)) |field| {
                if (!implCopy(field.field_type))
                    return false;
            }
            // all type of fields are copyable
            return true;
        }
        return false;
    }
}

comptime {
    assert(implCopy(u32));
    assert(implCopy(struct { val: u32 }));
    assert(implCopy(f64));
    assert(!implCopy(*u64));
    assert(implCopy(?f64));
    assert(implCopy(struct { val: f32 }));
    assert(!implCopy([]const u8));
    assert(!implCopy([*]f64));
    assert(implCopy([5]u32));
    const U = union(enum) { Tag1, Tag2, Tag3 };
    assert(implCopy(U));
    assert(!implCopy(*U));
    assert(!implCopy(*const U));
    const OverflowError = error{Overflow};
    assert(implCopy(@TypeOf(.Overflow))); // EnumLiteral
    assert(implCopy(OverflowError)); // ErrorSet
    assert(implCopy(OverflowError![2]U)); // ErrorUnion
    assert(implCopy(?(error{Overflow}![2]U)));
    assert(implCopy(struct { val: ?(error{Overflow}![2]U) }));
    assert(!implCopy(struct { val: ?(error{Overflow}![2]*const U) }));
}

pub fn isCopyable(comptime T: type) bool {
    comptime return is_or_ptrto(implCopy)(T);
}

pub fn implClone(comptime T: type) bool {
    comptime {
        if (implCopy(T))
            return true;

        if (have_type(T, "Self")) |Self| {
            if (have_type(T, "CloneError")) |CloneError| {
                if (!trait.is(.ErrorSet)(CloneError))
                    return false;
                if (have_fun(T, "clone")) |clone_ty| {
                    if (clone_ty == fn (Self) CloneError!Self)
                        return true;
                }
            }
        }
        return false;
    }
}

comptime {
    assert(implClone(u32));
    assert(implClone(f64));
    assert(!implClone(*u32));
    assert(!implClone(*const u32));
    assert(implClone([16]u32));
    assert(!implClone([]u32));
    const T = struct {
        pub const Self: type = @This();
        pub const CloneError: type = error{CloneError};
        x: u32,
        pub fn clone(self: *const Self) CloneError!Self {
            return .{ .x = self.x };
        }
    };
    assert(implClone(T));
    assert(implClone([2]T));
    assert(!implClone([]const T));
    assert(!implClone(*T));
    assert(!implClone([*]const T));
    assert(implClone(struct { val: [2]T }));
    assert(!implClone(*struct { val: [2]T }));
}

pub fn isClonable(comptime T: type) bool {
    comptime return is_or_ptrto(implClone)(T);
}

pub const Clone = struct {
    pub const EmptyError = error{};

    pub fn ResultType(comptime T: type) type {
        comptime assert(isClonable(T));
        const Out = deref_type(T);
        const Err = have_type(Out, "CloneError") orelse EmptyError;
        return Err!Out;
    }

    fn clone_impl(value: anytype) ResultType(@TypeOf(value)) {
        const T = @TypeOf(value);
        const E = std.meta.Child(T);
        if (comptime have_fun(E, "clone")) |_|
            return value.clone();
        comptime assert(implCopy(E));
        return value.*;
    }

    pub fn clone(value: anytype) ResultType(@TypeOf(value)) {
        const T = @TypeOf(value);
        comptime assert(isClonable(T));

        if (comptime !trait.isSingleItemPtr(T))
            return clone_impl(&value);
        return clone_impl(value);
    }
};

test "Clone" {
    const clone = Clone.clone;
    try testing.expectEqual(@as(error{}!u32, 5), clone(@as(u32, 5)));
    try testing.expectEqual(@as(error{}!comptime_int, 5), clone(5));
    try testing.expectEqual(@as(error{}![3]u32, [_]u32{ 1, 2, 3 }), clone([_]u32{ 1, 2, 3 }));
    const val: u64 = 42;
    const ptr = &val;
    try testing.expectEqual(@as(error{}!u64, ptr.*), clone(ptr));

    var seq = range.range(@as(u32, 0), 5);
    // consume head of 3elems
    try testing.expectEqual(@as(u32, 0), seq.next().?);
    try testing.expectEqual(@as(u32, 1), seq.next().?);
    try testing.expectEqual(@as(u32, 2), seq.next().?);
    // branch from the sequence
    var seq2 = Clone.clone(seq) catch unreachable;
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

fn implPartialOrd(comptime T: type) bool {
    if (trait.is(.Bool)(T))
        return true;
    // primitive type
    if (trait.isNumber(T))
        return true;
    // complex type impl 'partial_cmp' method
    if (have_fun(T, "partial_cmp")) |ty| {
        if (ty == fn (*const T, *const T) ?std.math.Order)
            return true;
    }
    return false;
}

pub fn isPartialOrd(comptime T: type) bool {
    comptime return is_or_ptrto(implPartialOrd)(T);
}

comptime {
    assert(isPartialOrd(u32));
    assert(isPartialOrd(*const u64));
    assert(isPartialOrd(i64));
    assert(isPartialOrd(*const i64));
    assert(!isPartialOrd(*[]const i64));
    assert(!isPartialOrd([8]u64));
    assert(isPartialOrd(f64));
    assert(!isPartialOrd(@Vector(4, u32)));
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
            comptime assert(implPartialOrd(E));
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

test "PartialOrd" {
    const five: u32 = 5;
    const six: u32 = 6;
    try testing.expectEqual(PartialOrd.partial_cmp(five, six), math.Order.lt);
    try testing.expectEqual(PartialOrd.partial_cmp(&five, &six), math.Order.lt);
    const C = struct {
        x: u32,
        fn new(x: u32) @This() {
            return .{ .x = x };
        }
        fn partial_cmp(self: *const @This(), other: *const @This()) ?math.Order {
            return std.math.order(self.x, other.x);
        }
    };
    try testing.expectEqual(C.new(5).partial_cmp(&C.new(6)), math.Order.lt);
    try testing.expectEqual(C.new(6).partial_cmp(&C.new(6)), math.Order.eq);
    try testing.expectEqual(C.new(6).partial_cmp(&C.new(5)), math.Order.gt);
}

fn implOrd(comptime T: type) bool {
    comptime {
        if (!implPartialOrd(T))
            return false;
        // primitive type
        if (trait.isIntegral(T))
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
        return is_or_ptrto(implOrd)(T);
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
    assert(!isOrd(@Vector(4, u32)));
    assert(!isOrd(@Vector(4, f64)));
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

/// Trivially comparable with `==`.
///
/// # Details
/// Checks that values of the type `T` is comparable with operator `==`.
/// Except for pointer types.
pub fn implTrivialEq(comptime T: type) bool {
    comptime {
        if (trait.isNumber(T))
            return true;
        if (trait.is(.Void)(T))
            return true;
        if (trait.is(.Bool)(T) or trait.is(.Null)(T))
            return true;
        // Result of comparison should be @Vector(_, bool).
        // if (trait.is(.Vector)(T))
        //     return implTrivialEq(std.meta.Child(T));
        if (trait.is(.Enum)(T))
            return implTrivialEq(@typeInfo(T).Enum.tag_type);
        if (trait.is(.EnumLiteral)(T))
            return true;
        if (trait.is(.ErrorSet)(T))
            return true;
        if (trait.is(.Fn)(T))
            return true;
        return false;
    }
}

comptime {
    assert(@as(u32, 1) == @as(u32, 1));
    assert(null == null);
    assert(true == true);
    assert(true != false);
    // assert(@Vector(2, u32){ 0, 0 } == @Vector(2, u32){ 0, 0 });
    const E = enum { EA, EB, EC };
    assert(E.EA == E.EA);
    assert(.EB == .EB);
    assert(.EB != .EC);
    const Err = error{ ErrA, ErrB, ErrC };
    assert(Err.ErrA == Err.ErrA);
    assert(Err.ErrB != Err.ErrC);
}

pub fn implPartialEq(comptime T: type) bool {
    comptime {
        if (implTrivialEq(T))
            return true;
        if (trait.is(.Array)(T) or trait.is(.Optional)(T))
            return implPartialEq(std.meta.Child(T));
        if (trait.is(.Vector)(T) and implTrivialEq(std.meta.Child(T)))
            return implPartialEq(std.meta.Child(T));
        if (trait.is(.ErrorUnion)(T) and implPartialEq(@typeInfo(T).ErrorUnion.payload))
            return true;
        if (have_fun(T, "eq")) |ty|
            return ty == fn (*const T, *const T) bool;
        return false;
    }
}

comptime {
    assert(implPartialEq(bool));
    assert(implPartialEq(void));
    assert(implPartialEq(@TypeOf(null)));
    assert(implPartialEq(std.meta.Vector(4, u32)));
    assert(implPartialEq(u32));
    assert(!implPartialEq(struct { val: f32 }));
    assert(implPartialEq(struct {
        val: u32,

        pub fn eq(self: *const @This(), other: *const @This()) bool {
            return self.val == other.val;
        }
    }));
    assert(implPartialEq(f64));
    assert(!implPartialEq(*u64));
    assert(implPartialEq(?f64));
    assert(!implPartialEq(?*f64));
    assert(!implPartialEq([]const u8));
    assert(!implPartialEq([*]f64));
    assert(implPartialEq([5]u32));
    assert(implPartialEq(enum { A, B, C }));
    const U = union(enum) { Tag1, Tag2, Tag3 };
    assert(!implPartialEq(U));
    assert(!implPartialEq(*U));
    assert(!implPartialEq(*const U));
    const UEq = union(enum) {
        Tag1,
        Tag2,
        Tag3,
        pub fn eq(self: *const @This(), other: *const @This()) bool {
            return std.meta.activeTag(self.*) == std.meta.activeTag(other.*);
        }
    };
    assert(implPartialEq(UEq));
    assert(!implPartialEq(*UEq));
    assert(!implPartialEq(*const UEq));
    const OverflowError = error{Overflow};
    assert(implPartialEq(@TypeOf(.Overflow))); // EnumLiteral
    assert(implPartialEq(OverflowError)); // ErrorSet
    assert(!implPartialEq(OverflowError![2]U)); // ErrorUnion
    assert(!implPartialEq(?(error{Overflow}![2]U)));
    assert(implPartialEq(?(error{Overflow}![2]UEq)));
    assert(!implPartialEq(struct { val: ?(error{Overflow}![2]U) }));
    assert(implPartialEq(struct {
        val: ?(error{Overflow}![2]UEq),
        pub fn eq(self: *const @This(), other: *const @This()) bool {
            return PartialEq.eq(self, other);
        }
    }));
    assert(!implPartialEq(struct { val: ?(error{Overflow}![2]*const U) }));
    assert(implPartialEq(struct {
        val: u32,
        pub fn eq(self: *const @This(), other: *const @This()) bool {
            return self.val == other.val;
        }
    }));
    assert(implPartialEq(struct {
        val: *u32,
        pub fn eq(self: *const @This(), other: *const @This()) bool {
            return self.val == other.val;
        }
    }));
}

pub fn isPartialEq(comptime T: type) bool {
    comptime return is_or_ptrto(implPartialEq)(T);
}

pub const PartialEq = struct {
    fn eq_array(comptime T: type, x: T, y: T) bool {
        comptime assert(trait.isPtrTo(.Array)(T));
        if (x.len != y.len)
            return false;
        for (x) |xv, i| {
            if (!eq_impl(&xv, &y[i]))
                return false;
        }
        return true;
    }

    fn eq_optional(comptime T: type, x: T, y: T) bool {
        comptime assert(trait.isPtrTo(.Optional)(T));
        if (x.*) |xv| {
            return if (y.*) |yv| eq_impl(&xv, &yv) else false;
        } else {
            return y.* == null;
        }
    }

    fn eq_vector(comptime T: type, x: T, y: T) bool {
        comptime assert(trait.isPtrTo(.Vector)(T));
        var i: usize = 0;
        while (i < @typeInfo(std.meta.Child(T)).Vector.len) : (i += 1) {
            if (x.*[i] != y.*[i])
                return false;
        }
        return true;
    }

    fn eq_error_union(comptime T: type, x: T, y: T) bool {
        comptime assert(trait.isPtrTo(.ErrorUnion)(T));
        if (x.*) |xv| {
            return if (y.*) |yv| eq_impl(&xv, &yv) else |_| false;
        } else |xv| {
            return if (y.*) |_| false else |yv| xv == yv;
        }
    }

    fn eq_impl(x: anytype, y: @TypeOf(x)) bool {
        const T = @TypeOf(x);
        comptime assert(trait.isSingleItemPtr(T));
        const E = std.meta.Child(T);
        comptime assert(implPartialEq(E));

        if (comptime implTrivialEq(E))
            return x.* == y.*;

        if (comptime trait.is(.Array)(E))
            return eq_array(T, x, y);

        if (comptime trait.is(.Optional)(E))
            return eq_optional(T, x, y);

        if (comptime trait.is(.Vector)(E))
            return eq_vector(T, x, y);

        if (comptime trait.is(.ErrorUnion)(E))
            return eq_error_union(T, x, y);

        if (comptime have_fun(E, "eq")) |_|
            return x.eq(y);

        unreachable;
    }

    /// Compare the values
    ///
    /// # Details
    /// The type of values are required to satisfy `isPartialEq`.
    ///
    pub fn eq(x: anytype, y: @TypeOf(x)) bool {
        const T = @TypeOf(x);
        comptime assert(isPartialEq(T));

        if (comptime !trait.isSingleItemPtr(T))
            return eq_impl(&x, &y);
        return eq_impl(x, y);
    }

    pub fn ne(x: anytype, y: @TypeOf(x)) bool {
        return !eq(x, y);
    }
};

test "PartialEq" {
    {
        const x: u32 = 5;
        const y: u32 = 42;
        try testing.expect(!PartialEq.eq(x, y));
        try testing.expect(!PartialEq.eq(&x, &y));
    }
    {
        const x: u32 = 5;
        const y: u32 = 42;
        const xp: *const u32 = &x;
        const yp: *const u32 = &y;
        try testing.expect(!PartialEq.eq(xp, yp));
    }
    {
        const arr1 = [_]u32{ 0, 1, 2 };
        const arr2 = [_]u32{ 0, 1, 2 };
        try testing.expect(PartialEq.eq(arr1, arr2));
    }
    {
        const vec1 = std.meta.Vector(4, u32){ 0, 1, 2, 3 };
        const vec2 = std.meta.Vector(4, u32){ 0, 1, 2, 4 };
        try testing.expect(PartialEq.eq(&vec1, &vec1));
        try testing.expect(!PartialEq.eq(&vec1, &vec2));
    }
    // {
    //     const x: u32 = 5;
    //     const y: u32 = 42;
    //     const arr1 = [_]*const u32{&x};
    //     const arr2 = [_]*const u32{&y};
    //     try testing.expect(!PartialEq.eq(&arr1, &arr2));
    // }
    {
        const T = struct {
            val: u32,
            fn new(val: u32) @This() {
                return .{ .val = val };
            }
            // impl `eq` manually
            pub fn eq(self: *const @This(), other: *const @This()) bool {
                return self.val == other.val;
            }
        };
        const x = T.new(5);
        const y = T.new(5);
        try testing.expect(PartialEq.eq(x, y));
        const arr1 = [_]T{x};
        const arr2 = [_]T{y};
        try testing.expect(PartialEq.eq(&arr1, &arr2));
        const arr11 = [1]?[1]T{@as(?[1]T, [_]T{x})};
        const arr22 = [1]?[1]T{@as(?[1]T, [_]T{y})};
        try testing.expect(PartialEq.eq(&arr11, &arr22));
        // const arr1p = [_]*const T{&x};
        // const arr2p = [_]*const T{&y};
        // try testing.expect(PartialEq.eq(&arr1p, &arr2p));
    }
}
