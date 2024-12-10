const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("10.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var list: std.ArrayListUnmanaged([10][2]usize) = .{};
    defer list.deinit(allocator);
    var count: usize = 0;
    var i: usize = 0;
    const x_max, const y_max = aoc.dimensions(input);
    while (std.mem.indexOfScalarPos(u8, input, i, '0')) |offset| {
        list.clearRetainingCapacity();
        i = offset + 1;
        const directions: []const aoc.Direction = &.{ .north, .east, .south, .west };
        const coords = aoc.indexToCoordinates(offset, input.len, x_max + 1) catch unreachable;
        var i_path: [10][2]usize = undefined;
        i_path[0] = .{ coords[0], coords[1] };
        try list.append(allocator, i_path);
        for (0..9) |idx| {
            const byte: u8 = @intCast('0' + idx);
            const slice = try list.toOwnedSlice(allocator);
            defer allocator.free(slice);
            for (slice) |path| {
                const i_x, const i_y = path[idx];
                for (directions) |direction| {
                    const x, const y = direction.walk(i_x, i_y, x_max - 1, y_max - 1) catch continue;
                    const byte_offset = aoc.coordinatesToIndex(x, y, x_max, y_max) catch unreachable;
                    if (input[byte_offset] != byte + 1) continue;
                    const new_path = try list.addOne(allocator);
                    @memcpy(new_path, &path);
                    new_path[idx + 1] = .{ x, y };
                }
            }
        }
        count += list.items.len;
    }
    return count;
}

test {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(81, output);
}
