const std = @import("std");
pub const basis = @import("basis_concept");

const tuple = @import("tuple.zig");
const compat = @import("compat.zig");

const trait = std.meta.trait;
const assert = std.debug.assert;

const Tuple1 = tuple.Tuple1;

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
        if (compat.newer_zig091)
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

// On zig-0.10.0, `@hasDecl` crashes.
fn hasDecl(comptime T: type, comptime name: []const u8) bool {
    comptime {
        switch (@typeInfo(T)) {
            .Struct, .Union, .Enum, .Opaque => {
                for (std.meta.declarations(T)) |decl| {
                    if (decl.is_pub) {
                        if (std.mem.eql(u8, decl.name, name))
                            return true;
                    }
                }
                return false;
            },
            else => return false,
        }
    }
}

pub fn have_fun(comptime T: type, comptime name: []const u8) ?type {
    comptime {
        if (compat.newer_zig091) {
            if (!std.meta.trait.isContainer(T))
                return null;
            if (!hasDecl(T, name))
                return null;
            return @as(?type, @TypeOf(@field(T, name)));
        } else {
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
