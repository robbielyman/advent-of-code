const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("12.txt", .{});
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
    var count: usize = 0;
    const max_x, const max_y = aoc.dimensions(input);
    var visited: std.AutoArrayHashMapUnmanaged([2]u16, void) = .{};
    defer visited.deinit(allocator);
    var map: std.AutoArrayHashMapUnmanaged([2]u16, void) = .{};
    defer map.deinit(allocator);
    const directions: []const aoc.Direction = &.{ .north, .east, .south, .west };

    var idx: usize = 0;
    while (idx < input.len) : (idx += 1) {
        const i_coord = aoc.indexToCoordinates(idx, input.len, max_x + 1) catch |err| switch (err) {
            error.Delimiter => continue,
            error.Overflow => unreachable,
        };
        if (visited.get(.{ @intCast(i_coord[0]), @intCast(i_coord[1]) })) |_| continue;
        const value = input[idx];
        var area: usize = 0;
        var perimeter: usize = 0;
        var slice = try allocator.alloc([2]u16, 1);
        defer allocator.free(slice);
        slice[0] = .{ @intCast(i_coord[0]), @intCast(i_coord[1]) };
        while (slice.len > 0) {
            map.clearRetainingCapacity();
            for (slice) |coord| {
                area += 1;
                try visited.put(allocator, coord, {});
                for (directions) |direction| {
                    const x, const y = direction.walk(coord[0], coord[1], max_x - 1, max_y - 1) catch {
                        perimeter += 1;
                        continue;
                    };
                    const offset = aoc.coordinatesToIndex(x, y, max_x, max_y) catch unreachable;
                    if (input[offset] == value) {
                        if (visited.get(.{ @intCast(x), @intCast(y) }) == null)
                            try map.put(allocator, .{ @intCast(x), @intCast(y) }, {});
                    } else perimeter += 1;
                }
            }
            allocator.free(slice);
            slice = try allocator.dupe([2]u16, map.keys());
        }
        count += area * perimeter;
    }
    return count;
}

test {
    const input =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(1930, output);
}
