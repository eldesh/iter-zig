const std = @import("std");
const iter = @import("iter-zig");

pub fn main() anyerror!void {
    var arr = [_]u32{ 1, 2, 3 };
    var it = iter.SliceIter(u32).new(arr[0..]);
    while (it.next()) |item| {
        std.debug.print("item: {}\n", .{item.*});
    }
}
