const std = @import("std");

pub fn process(_: std.mem.Allocator, input: []const u8) ![16]u8 {
    var arr = "abcdefghijklmnop".*;
    var it = std.mem.tokenizeScalar(u8, input, ',');
    while (it.next()) |move| {
        errdefer std.log.err("bad token: {s}", .{move});
        switch (move[0]) {
            's' => {
                const size = try std.fmt.parseInt(u32, move[1..], 10);
                const copy = arr;
                for (0..16, &copy) |idx, val| {
                    const new = idx + size;
                    arr[new % 16] = val;
                }
            },
            'x' => {
                const i, const j = blk: {
                    const slash = std.mem.indexOfScalar(u8, move, '/') orelse return error.BadInput;
                    const i = try std.fmt.parseInt(u8, move[1..slash], 10);
                    const j = try std.fmt.parseInt(u8, move[slash + 1 ..], 10);
                    break :blk .{ i, j };
                };
                const copy = arr[i];
                arr[i] = arr[j];
                arr[j] = copy;
            },
            'p' => {
                if (move.len != 4 or move[2] != '/') return error.BadInput;
                const i = std.mem.indexOfScalar(u8, &arr, move[1]) orelse return error.BadInput;
                const j = std.mem.indexOfScalar(u8, &arr, move[3]) orelse return error.BadInput;
                arr[i] = move[3];
                arr[j] = move[1];
            },
            else => return error.BadInput,
        }
    }
    return arr;
}
