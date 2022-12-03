const std = @import("std");
const builtin = @import("builtin");
pub const basis = @import("basis_concept");

const tuple = @import("tuple.zig");

const SemVer = std.SemanticVersion;
const trait = std.meta.trait;
const assert = std.debug.assert;
const Tuple1 = tuple.Tuple1;

// pub usingnamespace basis;
/// workaround criteria
pub const zig091 = SemVer.parse("0.9.1") catch unreachable;
/// *this* is older than or equals to zig-0.9.1 (<= 0.9.1).
pub const older_zig091: bool = builtin.zig_version.order(zig091).compare(.lte);
/// *this* is newer than zig-0.9.1 (> 0.9.1)
pub const newer_zig091: bool = builtin.zig_version.order(zig091).compare(.gt);

pub fn Func(comptime Arg: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg) Result;
        } else {
            return fn (Arg) Result;
        }
    }
}

pub fn Func2(comptime Arg1: type, comptime Arg2: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg1, Arg2) Result;
        } else {
            return fn (Arg1, Arg2) Result;
        }
    }
}

/// Compare std tuple types rather than values
///
/// # Details
/// Compare arity and field types each other.
/// For zig 0.9.1, the `==` operator can not comparing std tuples correctly.
/// Then the below expression evaluated always to false.
/// ```
/// std.meta.Tuple(&[_]type{u32}) == std.meta.Tuple(&[_]type{u32})
/// ```
pub fn eqTupleType(comptime exp: type, comptime act: type) bool {
    comptime {
        // workaround criteria
        const old_zig = SemVer.parse("0.9.1") catch unreachable;
        if (builtin.zig_version.order(old_zig) == .gt)
            return exp == act;

        if (!trait.isTuple(exp)) return false;
        if (!trait.isTuple(act)) return false;
        return eqTupleTypeImpl(exp, act);
    }
}

fn eqTupleTypeImpl(comptime exp: type, comptime act: type) bool {
    comptime {
        assert(trait.isTuple(exp));
        assert(trait.isTuple(act));

        const expfs = std.meta.fields(exp);
        const actfs = std.meta.fields(act);
        if (expfs.len != actfs.len) // compare arity
            return false;

        const isTuple = trait.isTuple;
        inline for (expfs) |expf, i| {
            if (isTuple(expf.field_type) and isTuple(actfs[i].field_type))
                return eqTupleTypeImpl(expf.field_type, actfs[i].field_type);
            if (expf.field_type != actfs[i].field_type)
                return false;
        }
        return true;
    }
}

pub fn assertEqualTupleType(comptime x: type, comptime y: type) void {
    if (!eqTupleType(x, y)) unreachable; // assertion failure
}

pub fn assertNotEqualTupleType(comptime x: type, comptime y: type) void {
    if (eqTupleType(x, y)) unreachable; // assertion failure
}

comptime {
    const Tuple = std.meta.Tuple;
    assertEqualTupleType(
        Tuple(&[_]type{u32}),
        Tuple(&[_]type{u32}),
    );
    assertNotEqualTupleType(
        Tuple(&[_]type{ u32, u32 }),
        Tuple(&[_]type{u32}),
    );
    assertEqualTupleType(
        Tuple(&[_]type{ u32, i64 }),
        Tuple(&[_]type{ u32, i64 }),
    );
    assertNotEqualTupleType(
        Tuple(&[_]type{ i64, u32 }),
        Tuple(&[_]type{ i64, u32, f32 }),
    );
    assertNotEqualTupleType(
        Tuple(&[_]type{}),
        Tuple(&[_]type{ u32, i64 }),
    );
    assertEqualTupleType(
        Tuple(&[_]type{
            Tuple(&[_]type{ u32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
        Tuple(&[_]type{
            Tuple(&[_]type{ u32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
    );
    assertNotEqualTupleType(
        Tuple(&[_]type{
            Tuple(&[_]type{ u32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
        Tuple(&[_]type{
            Tuple(&[_]type{ i32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
    );
    assertNotEqualTupleType(
        Tuple(&[_]type{
            Tuple(&[_]type{ u32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
        Tuple(&[_]type{
            Tuple(&[_]type{ i32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
    );
    assertNotEqualTupleType(
        Tuple(&[_]type{
            Tuple(&[_]type{ u32, i64 }),
            f64,
        }),
        Tuple(&[_]type{
            Tuple(&[_]type{ i32, i64 }),
            Tuple(&[_]type{ u32, i64 }),
        }),
    );
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

pub fn have_type(comptime T: type, comptime name: []const u8) ?type {
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

pub fn have_field(comptime T: type, comptime name: []const u8) ?type {
    comptime {
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
}

/// Check that the type `T` is an Iterator
pub fn isIterator(comptime T: type) bool {
    comptime {
        if (have_type(T, "Self")) |Self| {
            if (have_type(T, "Item")) |Item| {
                if (have_fun(T, "next")) |next_ty| {
                    return next_ty == fn (*Self) ?Item;
                }
            }
        }
        return false;
    }
}

pub fn have_fun(comptime T: type, comptime name: []const u8) ?type {
    comptime {
        switch (@typeInfo(T)) {
            .Struct => |Struct| {
                for (Struct.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, name))
                        return @TypeOf(@field(T, name));
                }
            },
            .Union => |Union| {
                for (Union.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, name))
                        return @TypeOf(@field(T, name));
                }
            },
            .Enum => |Enum| {
                for (Enum.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, name))
                        return @TypeOf(@field(T, name));
                }
            },
            .Opaque => |Opaque| {
                for (Opaque.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, name))
                        return @TypeOf(@field(T, name));
                }
            },
            else => {},
        }
        return null;
    }
}

comptime {
    assert(!isIterator(u32));
    assert(!isIterator([]const u8));
    assert(!isIterator([5]u64));
}

/// Returns error type of the error union type `R`.
pub fn err_type(comptime R: type) type {
    comptime assert(trait.is(.ErrorUnion)(R));
    return comptime @typeInfo(R).ErrorUnion.error_set;
}

/// Returns 'right' (not error) type of the error union type `R`.
pub fn ok_type(comptime R: type) type {
    comptime assert(trait.is(.ErrorUnion)(R));
    return comptime @typeInfo(R).ErrorUnion.payload;
}

comptime {
    const FooError = error{Foo};
    assert(err_type(FooError!u32) == FooError);
    assert(ok_type(FooError!u32) == u32);
}

fn is_func_type(comptime F: type) bool {
    comptime {
        const info = @typeInfo(F);
        return switch (info) {
            .Fn => true,
            else => false,
        };
    }
}

pub fn func_arity(comptime F: type) usize {
    comptime {
        assert(is_func_type(F));
        return @typeInfo(F).Fn.args.len;
    }
}

pub fn is_unary_func_type(comptime F: type) bool {
    comptime return is_func_type(F) and @typeInfo(F).Fn.args.len == 1;
}

pub fn is_binary_func_type(comptime F: type) bool {
    comptime return is_func_type(F) and @typeInfo(F).Fn.args.len == 2;
}

pub fn domain(comptime F: type) type {
    comptime return std.meta.ArgsTuple(F);
}

pub fn codomain(comptime F: type) type {
    comptime {
        assert(is_func_type(F));
        if (@typeInfo(F).Fn.return_type) |ty| {
            return ty;
        } else {
            return void;
        }
    }
}

comptime {
    assertEqualTupleType(domain(fn (u32) u16), Tuple1(u32).StdTuple);
    assert(codomain(fn (u32) u16) == u16);
    assertEqualTupleType(domain(fn (u32) []const u8), Tuple1(u32).StdTuple);
    assert(codomain(fn (u32) []const u8) == []const u8);
}

/// Convert a function type `F` to `Func` type.
/// `F` must be a unary function type.
pub fn toFunc(comptime F: type) type {
    comptime {
        const A = domain(F);
        const R = codomain(F);
        return Func(@typeInfo(A).Struct.fields[0].field_type, R);
    }
}

/// Convert a function type `F` to `Func` type.
/// `F` must be a binary function type.
pub fn toFunc2(comptime F: type) type {
    comptime {
        const A = domain(F);
        const R = codomain(F);
        return Func2(
            @typeInfo(A).Struct.fields[0].field_type,
            @typeInfo(A).Struct.fields[1].field_type,
            R,
        );
    }
}
