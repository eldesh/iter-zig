const std = @import("std");

const iter = @import("./iter.zig");

const SliceIter = @import("./to_iter.zig").SliceIter;
const ArrayIter = @import("./to_iter.zig").ArrayIter;
const ArrayListIter = @import("./to_iter.zig").ArrayListIter;
const SinglyLinkedListIter = @import("./to_iter.zig").SinglyLinkedListIter;

const testing = std.testing;
const assert = std.debug.assert;
const debug = std.debug.print;

pub fn have_type(comptime T: type, name: []const u8) ?type {
    if (!comptime @hasDecl(T, name)) {
        return null;
    }
    const field = @field(T, name);
    if (@typeInfo(@TypeOf(field)) == .Type) {
        return field;
    }
    return null;
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
        else => false,
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
    assert(isIterator(ArrayIter(u32, 3)));
    assert(isIterator(SliceIter(u32)));
    assert(isIterator(ArrayListIter(u32)));
    assert(isIterator(SinglyLinkedListIter(u32)));
}

fn impl_map(comptime T: type) type {
    assert(isIterator(T));

    // if (!have_fun(T, "map")) {
    //     const TypeInfo = std.builtin.TypeInfo;
    //     var info: TypeInfo = @typeInfo(T);
    //     var decls: [info.Struct.decls.len+1]TypeInfo.Declaration = undefined;
    //     var i = 0;
    //     while (i < info.Struct.decls.len) : (i += 1) {
    //         decls[i] = info.Struct.decls[i];
    //     }
    //     decls[i] = @typeInfo(struct {
    //         pub fn map(self: *Self, f: F) IterMap(Self, F) {
    //         }
    //     }).Struct.decls[0];
    // }
    // var ty = @Type(info);
    // info.Struct.decls[0].data = .{ .Type = ty };
    // return @Type(ty);
}

test "impl_map" {
    const SliceIterMap = impl_map(SliceIter(u32));
    assert(isIterator(SliceIterMap));
    _ = SliceIterMap;
}
