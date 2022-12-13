const std = @import("std");
const builtin = @import("builtin");
const tuple = @import("tuple.zig");

const assert = std.debug.assert;

// pub usingnamespace basis;
/// workaround criteria
pub const zig091: std.SemanticVersion = std.SemanticVersion.parse("0.9.1") catch unreachable;
/// *this* is older than or equals to zig-0.9.1 (<= 0.9.1).
pub const older_zig091: bool = builtin.zig_version.order(zig091).compare(.lte);
/// *this* is newer than zig-0.9.1 (> 0.9.1)
pub const newer_zig091: bool = builtin.zig_version.order(zig091).compare(.gt);

/// Abstraction of type of unary function type
pub fn Func(comptime Arg: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg) Result;
        } else {
            return fn (Arg) Result;
        }
    }
}

/// Abstraction of type of binary function type
///
/// # Details
/// Abstract function types for Zig 0.9.0 and 0.10.0.
pub fn Func2(comptime Arg1: type, comptime Arg2: type, comptime Result: type) type {
    comptime {
        if (newer_zig091) {
            return *const fn (Arg1, Arg2) Result;
        } else {
            return fn (Arg1, Arg2) Result;
        }
    }
}

fn domain(comptime F: type) type {
    comptime return std.meta.ArgsTuple(F);
}

fn codomain(comptime F: type) type {
    comptime {
        assert(std.meta.trait.is(.Fn)(F));
        if (@typeInfo(F).Fn.return_type) |ty| {
            return ty;
        } else {
            return void;
        }
    }
}

comptime {
    assert(std.meta.fields(domain(fn (u32) u16))[0].field_type == u32);
    assert(codomain(fn (u32) u16) == u16);
    assert(std.meta.fields(domain(fn (u32) []const u8))[0].field_type == u32);
    assert(codomain(fn (u32) []const u8) == []const u8);
}

/// Convert a function type `fn (A) R` to `Func(A, R)` type.
///
/// # Details
/// Convert a function type `fn (A) R` to `Func(A, R)` type.
/// Where the `F` must be a unary function type.
pub fn toFunc(comptime F: type) type {
    comptime {
        const A = domain(F);
        const R = codomain(F);
        return Func(@typeInfo(A).Struct.fields[0].field_type, R);
    }
}

/// Convert a function type `F` to `Func` type.
///
/// # Details
/// Convert a function type `F` to `Func` type.
/// Where the `F` must be a binary function type.
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
