const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("15.txt", .{});
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

fn process(allocator: std.mem.Allocator, input: []const u8) !u32 {
    const split = std.mem.indexOf(u8, input, "\n\n") orelse return error.BadInput;
    var obstacles, const list, var robot = try parse(allocator, input[0..split]);
    defer obstacles.deinit(allocator);
    defer allocator.free(list);
    for (input[split + 2 ..]) |char| switch (char) {
        '^' => robot.push(.north, obstacles, list) catch {},
        '>' => robot.push(.east, obstacles, list) catch {},
        'v' => robot.push(.south, obstacles, list) catch {},
        '<' => robot.push(.west, obstacles, list) catch {},
        '\n' => {},
        else => unreachable,
    };
    var gps: u32 = 0;
    for (list) |coordinate| gps += coordinate.x + (100 * coordinate.y);
    return gps;
}

const Coordinate = packed struct {
    x: u16,
    y: u16,

    fn push(self: *Coordinate, direction: enum { north, east, south, west }, obstacles: Obstacles, list: []Coordinate) error{Obstructed}!void {
        const new: Coordinate = switch (direction) {
            .north => .{ .x = self.x, .y = self.y -| 1 },
            .east => .{ .x = self.x +| 1, .y = self.y },
            .south => .{ .x = self.x, .y = self.y +| 1 },
            .west => .{ .x = self.x -| 1, .y = self.y },
        };
        if (new.to() == self.to()) return error.Obstructed;
        if (obstacles.get(new)) |_| return error.Obstructed;
        if (std.mem.indexOfScalar(u32, @ptrCast(list), new.to())) |i| {
            try list[i].push(direction, obstacles, list);
        }
        self.* = new;
    }

    fn to(self: Coordinate) u32 {
        return @bitCast(self);
    }
};

const Obstacles = std.AutoArrayHashMapUnmanaged(Coordinate, void);

fn parse(allocator: std.mem.Allocator, map: []const u8) !struct { Obstacles, []Coordinate, Coordinate } {
    var list: std.ArrayListUnmanaged(Coordinate) = .{};
    defer list.deinit(allocator);
    var obstacles: Obstacles = .{};
    errdefer obstacles.deinit(allocator);

    var iterator = std.mem.tokenizeScalar(u8, map, '\n');
    var y: u16 = 0;
    var robot: Coordinate = undefined;
    while (iterator.next()) |line| {
        defer y += 1;
        for (line, 0..) |char, x|
            switch (char) {
                '#' => try obstacles.put(allocator, .{ .x = @intCast(x), .y = y }, {}),
                '@' => robot = .{ .x = @intCast(x), .y = y },
                '.' => {},
                'O' => try list.append(allocator, .{ .x = @intCast(x), .y = y }),
                else => unreachable,
            };
    }
    return .{ obstacles, try list.toOwnedSlice(allocator), robot };
}

test {
    const input =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
        \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
        \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
        \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
        \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
        \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
        \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
        \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
        \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
        \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
        \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
    ;

    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(10092, output);
}
