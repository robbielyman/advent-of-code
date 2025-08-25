const std = @import("std");
const assert = std.debug.assert;

pub fn process(gpa: std.mem.Allocator, input: []const u8) ![16]u8 {
    var arr: [16]u8 = "abcdefghijklmnop".*;
    var map: Map = .empty;
    defer map.deinit(gpa);
    for (0..1_000_000_000) |_| try dance(&map, gpa, &arr, input);
    return arr;
}

const Map = std.AutoArrayHashMapUnmanaged([16]u8, [16]u8);

fn dance(map: *Map, gpa: std.mem.Allocator, current: *[16]u8, input: []const u8) !void {
    const ret = try map.getOrPut(gpa, current.*);
    if (ret.found_existing) {
        current.* = ret.value_ptr.*;
        return;
    }
    var it = std.mem.tokenizeScalar(u8, input, ',');
    while (it.next()) |move| {
        errdefer std.log.err("bad token: {s}", .{move});
        switch (move[0]) {
            's' => {
                const size = try std.fmt.parseInt(u32, move[1..], 10);
                const copy = current.*;
                for (0..16, &copy) |idx, val| {
                    const new = idx + size;
                    current[new % 16] = val;
                }
            },
            'x' => {
                const i, const j = blk: {
                    const slash = std.mem.indexOfScalar(u8, move, '/') orelse return error.BadInput;
                    const i = try std.fmt.parseInt(u8, move[1..slash], 10);
                    const j = try std.fmt.parseInt(u8, move[slash + 1 ..], 10);
                    break :blk .{ i, j };
                };
                const copy = current[i];
                current[i] = current[j];
                current[j] = copy;
            },
            'p' => {
                if (move.len != 4 or move[2] != '/') return error.BadInput;
                const i = std.mem.indexOfScalar(u8, current, move[1]) orelse return error.BadInput;
                const j = std.mem.indexOfScalar(u8, current, move[3]) orelse return error.BadInput;
                current[i] = move[3];
                current[j] = move[1];
            },
            else => return error.BadInput,
        }
    }
    ret.value_ptr.* = current.*;
}
