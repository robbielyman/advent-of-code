const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("20.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input, 100);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8, cheats_at_least: u32) !u32 {
    const track = try buildTrack(allocator, input);
    defer allocator.free(track);
    var count: u32 = 0;
    for (0..track.len - 2) |i| {
        const cheat_start = track[i];
        for (i + 2..track.len) |j| {
            const cheat_end = track[j];
            const cheat_time = cheat_start.dist(cheat_end);
            if (cheat_time > 20) continue;
            const distance_covered = j - i;
            if (distance_covered >= cheats_at_least + cheat_time) count += 1;
        }
    }
    return count;
}

fn buildTrack(allocator: std.mem.Allocator, maze: []const u8) ![]Coord {
    var track: std.ArrayListUnmanaged(Coord) = .{};
    defer track.deinit(allocator);
    const x, const y = aoc.dimensions(maze);
    const offset = std.mem.indexOfScalar(u8, maze, 'S') orelse return error.BadInput;
    const s_x, const s_y = try aoc.indexToCoordinates(offset, maze.len, x + 1);
    var coord: Coord = .{ .x = @intCast(s_x), .y = @intCast(s_y) };
    const directions: []const aoc.Direction = &.{ .north, .east, .south, .west };
    try track.append(allocator, coord);
    var done = false;
    while (!done) {
        for (directions) |direction| {
            const n_x, const n_y = direction.walk(coord.x, coord.y, x - 1, y - 1) catch continue;
            const byte_offset = try aoc.coordinatesToIndex(n_x, n_y, x, y);
            const new_coord: Coord = .{ .x = @intCast(n_x), .y = @intCast(n_y) };
            switch (maze[byte_offset]) {
                '#', 'S' => continue,
                'E' => done = true,
                '.' => {
                    const start = track.items.len -| 2;
                    const skip = skip: {
                        for (track.items[start..]) |item|
                            if (item.to() == new_coord.to()) break :skip true;
                        break :skip false;
                    };
                    if (skip) continue;
                },
                else => unreachable,
            }
            try track.append(allocator, new_coord);
            coord = new_coord;
            break;
        } else unreachable;
    }
    return try track.toOwnedSlice(allocator);
}

const Coord = packed struct {
    x: u16,
    y: u16,

    fn to(coord: Coord) u32 {
        return @bitCast(coord);
    }

    fn dist(a: Coord, b: Coord) u16 {
        const d_x = @as(i32, a.x) - @as(i32, b.x);
        const d_y = @as(i32, a.y) - @as(i32, b.y);
        return @intCast(@abs(d_x) + @abs(d_y));
    }
};

test {
    const input =
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    ;
    var output: [4]u32 = undefined;
    const conditions: []const u32 = &.{ 70, 72, 74, 76 };
    for (&output, conditions) |*out, condition|
        out.* = try process(std.testing.allocator, input, condition);
    try std.testing.expectEqualSlices(u32, &.{ 12 + 22 + 4 + 3, 22 + 4 + 3, 4 + 3, 3 }, &output);
}
