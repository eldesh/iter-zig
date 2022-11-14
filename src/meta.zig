const std = @import("std");
const basis_concept = @import("basis_concept");

const range = @import("./range.zig");

const Range = range.Range;

const math = std.math;
const trait = std.meta.trait;
const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

pub usingnamespace basis_concept;

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
    comptime return if (trait.isSingleItemPtr(T))
        std.meta.Child(T)
    else
        T;
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
    comptime {
        assert(trait.isSingleItemPtr(T));
        return std.meta.Child(T);
    }
}

pub fn remove_const_pointer(comptime T: type) type {
    comptime {
        assert(trait.isSingleItemPtr(T) and trait.isConstPtr(T));
        var info = @typeInfo(T);
        info.Pointer.is_const = false;
        return remove_pointer(@Type(info));
    }
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
}
