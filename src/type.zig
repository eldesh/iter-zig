const std = @import("std");

const iter = @import("./iter.zig");

const SliceIter = @import("./to_iter.zig").SliceIter;
const ArrayIter = @import("./to_iter.zig").ArrayIter;
const ArrayListIter = @import("./to_iter.zig").ArrayListIter;
const SinglyLinkedListIter = @import("./to_iter.zig").SinglyLinkedListIter;

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

fn isComparableType(comptime T: type) bool {
    comptime {
        // primitive type
        if (trait.isNumber(T) or trait.is(.Vector)(T))
            return true;
        // complex type impl 'cmp' method
        if (have_fun(T, "cmp")) |ty| {
            if (ty == fn (*const T, *const T) std.math.Order or
                ty == fn (T, T) std.math.Order)
            {
                return true;
            }
        }
        return false;
    }
}

// TODO: to be comparable tuple
// TODO: to be comparable optional
pub fn isComparable(comptime T: type) bool {
    comptime {
        // comparable type or ..
        if (isComparableType(T))
            return true;
        // a pointer type that points to comparable type
        if (trait.isSingleItemPtr(T) and isComparableType(std.meta.Child(T)))
            return true;
        return false;
    }
}

comptime {
    assert(isComparable(u32));
    assert(isComparable(*u32));
    assert(!isComparable([]u32));
    assert(!isComparable([*]u32));
    assert(isComparable(i64));
    assert(isComparable(*const i64));
    assert(!isComparable(*[]const i64));
    assert(!isComparable([8]u64));
    assert(isComparable(f64));
    const C = struct {
        val: u32,
        pub fn cmp(x: *const @This(), y: *const @This()) std.math.Order {
            _ = x;
            _ = y;
            return .lt;
        }
    };
    assert(isComparable(C));
    assert(isComparable(*C));
    const D = struct {
        val: u32,
        pub fn cmp(x: @This(), y: @This()) std.math.Order {
            _ = x;
            _ = y;
            return .lt;
        }
    };
    assert(isComparable(D));
    assert(isComparable(*D));
}

pub const Comparable = struct {
    /// General comparing function
    ///
    /// # Details
    /// Compares `Comparable` values.
    /// If the type of `x` is a primitive type, `cmp` would be used like `cmp(5, 6)`.
    /// And for others, like `cmp(&x, &y)` where the typeof x is comparable.
    pub fn cmp(x: anytype, y: @TypeOf(x)) std.math.Order {
        const T = @TypeOf(x);
        comptime assert(isComparable(T));

        // primitive types
        if (comptime trait.isNumber(T) or trait.is(.Vector)(T))
            return std.math.order(x, y);
        // pointer that points to
        if (comptime trait.isSingleItemPtr(T)) {
            const E = std.meta.Child(T);
            // primitive types
            if (comptime trait.isNumber(E) or trait.is(.Vector)(E))
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
    pub fn set(comptime T: type) fn (T, T) std.math.Order {
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
    assert(Comparable.set(u32)(0, 1) == .lt);
    assert(Comparable.set(*const u32)(pzero, pone) == .lt);
}
