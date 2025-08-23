const std = @import("std");
const knotHash = @import("10-02.zig").process;

pub fn process(allocator: std.mem.Allocator, raw_in: []const u8) !u32 {
    var it = std.mem.tokenizeAny(u8, raw_in, &.{ '\n', '\t', 0 });
    const input = it.next().?;
    var grid: [128]u128 = undefined;
    for (0..128) |i| {
        var buf: [16]u8 = @splat(0);
        var w: std.io.Writer = .{
            .buffer = &buf,
            .vtable = &.{
                .drain = std.io.Writer.failingDrain,
                .rebase = std.io.Writer.failingRebase,
            },
        };
        try w.print("{s}-{d}", .{ input, i });
        const hash = try knotHash(undefined, w.buffer[0..w.end]);
        const hex = try std.fmt.parseInt(u128, &hash, 16);
        // std.log.info("{b:0>128}", .{hex});
        grid[i] = hex;
    }

    var other: [128]u128 = @splat(0);
    var count: u32 = 0;
    var list: std.ArrayList([2]usize) = .empty;
    defer list.deinit(allocator);
    const one: u128 = 1;
    outer: while (true) : (count += 1) {
        list.clearRetainingCapacity();
        blk: for (&grid, &other, 0..) |in_row, row, j| {
            const rem = in_row - row;
            if (rem == 0) continue;
            for (0..128) |i| {
                const bit: u128 = one << @intCast(i);
                if (rem & bit != 0) {
                    try list.append(allocator, .{ i, j });
                    break :blk;
                }
            }
        } else break :outer;
        while (list.items.len > 0) {
            const i, const j = list.pop().?;
            if (grid[j] & one << @intCast(i) == 0 or other[j] & one << @intCast(i) != 0) continue;
            other[j] |= one << @intCast(i);
            if (i > 0) try list.append(allocator, .{ i - 1, j });
            if (j > 0) try list.append(allocator, .{ i, j - 1 });
            if (i < 127) try list.append(allocator, .{ i + 1, j });
            if (j < 127) try list.append(allocator, .{ i, j + 1 });
        }
    }
    return count;
}

test process {
    const input = "flqrgnkx";
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(1242, output);
}
