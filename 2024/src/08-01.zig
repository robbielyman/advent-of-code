const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("08.txt", .{});
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
    var antinodes: std.AutoHashMapUnmanaged([2]i32, void) = .{};
    defer antinodes.deinit(allocator);

    var list_of_coordinates: std.ArrayListUnmanaged([2]i32) = .{};
    defer list_of_coordinates.deinit(allocator);

    const max_x: i32, const max_y: i32 = dimensions: {
        const dimensions = aoc.dimensions(input);
        break :dimensions .{ @intCast(dimensions[0]), @intCast(dimensions[1]) };
    };

    for (frequencies) |frequency| {
        list_of_coordinates.clearRetainingCapacity();
        const len = aoc.countScalar(u8, input, frequency);
        try list_of_coordinates.ensureTotalCapacity(allocator, len);
        for (input, 0..) |byte, offset| {
            if (byte == frequency) {
                const x, const y = aoc.indexToCoordinates(offset, input.len, max_x) catch unreachable;
                list_of_coordinates.appendAssumeCapacity(.{ @intCast(x), @intCast(y) });
            }
        }

        for (list_of_coordinates.items, 0..) |coord_a, i| {
            for (list_of_coordinates.items[i + 1 ..]) |coord_b| {
                const d_x, const d_y = .{ coord_a[0] - coord_b[0], coord_a[1] - coord_b[1] };
                const new_nodes: [2][2]i32 = .{
                    .{ coord_b[0] - d_x, coord_b[1] - d_y },
                    .{ coord_a[0] + d_x, coord_a[1] + d_y },
                };
                for (&new_nodes) |antinode| {
                    const x, const y = antinode;
                    if (x < 0 or x >= max_x or y < 0 or y >= max_y) continue;
                    try antinodes.put(allocator, antinode, {});
                }
            }
        }
    }
    return antinodes.count();
}

const frequencies: []const u8 = frequencies: {
    var freqs: []const u8 = &.{};
    for ('0'..'9' + 1) |byte| freqs = freqs ++ .{byte};
    for ('A'..'Z' + 1) |byte| freqs = freqs ++ .{byte};
    for ('a'..'z' + 1) |byte| freqs = freqs ++ .{byte};
    break :frequencies freqs;
};

test {
    const input =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(14, output);
}
