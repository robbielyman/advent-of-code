const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("16.txt", .{});
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

fn process(allocator: std.mem.Allocator, maze: []const u8) !u32 {
    const x, const y = aoc.dimensions(maze);
    const end_idx = std.mem.indexOfScalar(u8, maze, 'E') orelse return error.BadInput;
    const end_x, const end_y = try aoc.indexToCoordinates(end_idx, maze.len, x + 1);
    const start_idx = std.mem.indexOfScalar(u8, maze, 'S') orelse return error.BadInput;
    const start_x, const start_y = try aoc.indexToCoordinates(start_idx, maze.len, x + 1);
    var list: std.ArrayListUnmanaged(Item) = .{};
    defer list.deinit(allocator);
    try list.append(allocator, .{
        .coord = .{ @intCast(start_x), @intCast(start_y) },
        .direction = .east,
        .score = 0,
    });

    var visited: std.AutoHashMapUnmanaged([2]u16, u32) = .{};
    defer visited.deinit(allocator);
    try visited.put(allocator, .{ @intCast(start_x), @intCast(start_y) }, 0);

    while (list.popOrNull()) |item| {
        for (item.next()) |next| {
            const offset = aoc.coordinatesToIndex(next.coord[0], next.coord[1], x, y) catch continue;
            if (maze[offset] == '#') continue;
            const ret = try visited.getOrPut(allocator, next.coord);
            if (!ret.found_existing or ret.value_ptr.* > next.score) {
                ret.value_ptr.* = next.score;
                try list.append(allocator, next);
            }
        }
        std.mem.sort(Item, list.items, {}, lessThan);
    }

    var counter: std.AutoHashMapUnmanaged([2]u16, void) = .{};
    defer counter.deinit(allocator);

    list.clearRetainingCapacity();
    const directions: []const aoc.Direction = &.{ .north, .east, .south, .west };
    for (directions) |direction| {
        try list.append(allocator, .{
            .coord = .{ @intCast(end_x), @intCast(end_y) },
            .score = visited.get(.{ @intCast(end_x), @intCast(end_y) }).?,
            .direction = direction,
        });
    }
    while (list.popOrNull()) |item| {
        for (item.prev()) |prev| {
            const score = visited.get(prev.coord) orelse continue;
            if (prev.score < score) continue;
            try list.append(allocator, prev);
            try counter.put(allocator, item.coord, {});
        }
        std.mem.sort(Item, list.items, {}, greaterThan);
    }
    try counter.put(allocator, .{ @intCast(start_x), @intCast(start_y) }, {});

    return @intCast(counter.count());
}

const Item = struct {
    coord: [2]u16,
    score: u32,
    direction: aoc.Direction,

    fn next(item: Item) [3]Item {
        return switch (item.direction) {
            .north => .{ .{
                .coord = .{ item.coord[0], item.coord[1] -| 1 },
                .score = item.score + 1,
                .direction = .north,
            }, .{
                .coord = .{ item.coord[0] -| 1, item.coord[1] },
                .score = item.score + 1001,
                .direction = .west,
            }, .{
                .coord = .{ item.coord[0] +| 1, item.coord[1] },
                .score = item.score + 1001,
                .direction = .east,
            } },
            .east => .{ .{
                .coord = .{ item.coord[0] +| 1, item.coord[1] },
                .score = item.score + 1,
                .direction = .east,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] -| 1 },
                .score = item.score + 1001,
                .direction = .north,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] +| 1 },
                .score = item.score + 1001,
                .direction = .south,
            } },
            .south => .{ .{
                .coord = .{ item.coord[0], item.coord[1] +| 1 },
                .score = item.score + 1,
                .direction = .south,
            }, .{
                .coord = .{ item.coord[0] -| 1, item.coord[1] },
                .score = item.score + 1001,
                .direction = .west,
            }, .{
                .coord = .{ item.coord[0] +| 1, item.coord[1] },
                .score = item.score + 1001,
                .direction = .east,
            } },
            .west => .{ .{
                .coord = .{ item.coord[0] -| 1, item.coord[1] },
                .score = item.score + 1,
                .direction = .west,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] -| 1 },
                .score = item.score + 1001,
                .direction = .north,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] +| 1 },
                .score = item.score + 1001,
                .direction = .south,
            } },
            else => unreachable,
        };
    }

    fn prev(item: Item) [3]Item {
        return switch (item.direction) {
            .north => .{ .{
                .coord = .{ item.coord[0], item.coord[1] +| 1 },
                .score = item.score -| 1,
                .direction = .north,
            }, .{
                .coord = .{ item.coord[0] +| 1, item.coord[1] },
                .score = item.score -| 1001,
                .direction = .west,
            }, .{
                .coord = .{ item.coord[0] -| 1, item.coord[1] },
                .score = item.score -| 1001,
                .direction = .east,
            } },
            .east => .{ .{
                .coord = .{ item.coord[0] -| 1, item.coord[1] },
                .score = item.score -| 1,
                .direction = .east,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] +| 1 },
                .score = item.score -| 1001,
                .direction = .north,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] -| 1 },
                .score = item.score -| 1001,
                .direction = .south,
            } },
            .south => .{ .{
                .coord = .{ item.coord[0], item.coord[1] -| 1 },
                .score = item.score -| 1,
                .direction = .south,
            }, .{
                .coord = .{ item.coord[0] +| 1, item.coord[1] },
                .score = item.score -| 1001,
                .direction = .west,
            }, .{
                .coord = .{ item.coord[0] -| 1, item.coord[1] },
                .score = item.score -| 1001,
                .direction = .east,
            } },
            .west => .{ .{
                .coord = .{ item.coord[0] +| 1, item.coord[1] },
                .score = item.score -| 1,
                .direction = .west,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] +| 1 },
                .score = item.score -| 1001,
                .direction = .north,
            }, .{
                .coord = .{ item.coord[0], item.coord[1] -| 1 },
                .score = item.score -| 1001,
                .direction = .south,
            } },
            else => unreachable,
        };
    }
};

fn greaterThan(_: void, a: Item, b: Item) bool {
    return a.score < b.score;
}

fn lessThan(_: void, a: Item, b: Item) bool {
    return a.score > b.score;
}

test {
    const first_input =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
    ;

    const second_input =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
    ;

    const first_output = try process(std.testing.allocator, first_input);
    const second_output = try process(std.testing.allocator, second_input);

    try std.testing.expectEqualSlices(u32, &.{ 45, 64 }, &.{ first_output, second_output });
}
