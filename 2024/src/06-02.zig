pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("06.txt", .{});
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
    var obstacles, const x_max, const y_max, const x, const y = try populate(allocator, input);
    defer obstacles.deinit(allocator);
    return try solve(allocator, &obstacles, x_max, y_max, x, y);
}

fn populate(allocator: std.mem.Allocator, input: []const u8) !struct {
    std.AutoHashMapUnmanaged([2]usize, void),
    usize,
    usize,
    usize,
    usize,
} {
    var obstacles: std.AutoHashMapUnmanaged([2]usize, void) = .{};
    errdefer obstacles.deinit(allocator);
    var y: usize = 0;
    var x_max: usize = undefined;
    var caret_x: usize = undefined;
    var caret_y: usize = undefined;
    var caret_found = false;
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        defer y += 1;
        x_max = line.len - 1;
        if (!caret_found) if (std.mem.indexOfScalar(u8, line, '^')) |c_x| {
            caret_found = true;
            caret_x = c_x;
            caret_y = y;
        };
        var x: usize = 0;
        while (std.mem.indexOfScalarPos(u8, line, x, '#')) |n_x| {
            x = n_x + 1;
            try obstacles.put(allocator, .{ n_x, y }, {});
        }
    }
    return .{ obstacles, x_max, y - 1, caret_x, caret_y };
}

fn solve(
    allocator: std.mem.Allocator,
    obstacles: *const std.AutoHashMapUnmanaged([2]usize, void),
    x_max: usize,
    y_max: usize,
    start_x: usize,
    start_y: usize,
) !usize {
    const Position = struct { [2]usize, Direction };
    var visited: std.AutoArrayHashMapUnmanaged(Position, void) = .{};
    defer visited.deinit(allocator);
    var count: usize = 0;
    for (0..y_max + 1) |o_y| {
        for (0..x_max + 1) |o_x| {
            if (o_x == start_x and o_y == start_y) continue;
            if (obstacles.get(.{ o_x, o_y })) |_| continue;
            defer visited.clearRetainingCapacity();
            var x = start_x;
            var y = start_y;
            var direction: Direction = .north;
            const looped = looped: {
                while (true) {
                    const res = try visited.getOrPut(allocator, .{ .{ x, y }, direction });
                    if (res.found_existing) break :looped true;
                    x, y = obstructed: {
                        var obstructed = true;
                        var n_x: usize = undefined;
                        var n_y: usize = undefined;
                        while (obstructed) {
                            n_x, n_y = direction.walk(x, y, x_max, y_max) catch break :looped false;
                            obstructed = o_x == n_x and o_y == n_y;
                            obstructed = obstructed or obstacles.get(.{ n_x, n_y }) != null;
                            if (obstructed) {
                                direction = switch (direction) {
                                    .north => .east,
                                    .east => .south,
                                    .south => .west,
                                    .west => .north,
                                    else => unreachable,
                                };
                            }
                        }
                        break :obstructed .{ n_x, n_y };
                    };
                }
            };
            if (looped) count += 1;
        }
    }
    return count;
}

test {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var obstacles, const x_max, const y_max, const x, const y = try populate(std.testing.allocator, input);
    defer obstacles.deinit(std.testing.allocator);

    try std.testing.expectEqual(8, obstacles.count());
    try std.testing.expectEqual(9, x_max);
    try std.testing.expectEqual(9, y_max);
    try std.testing.expectEqual(4, x);
    try std.testing.expectEqual(6, y);

    try std.testing.expectEqual(6, try solve(std.testing.allocator, &obstacles, x_max, y_max, x, y));
}

const Direction = @import("directions.zig").Direction;
const std = @import("std");
