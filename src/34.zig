const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const map: []const []const u8 = map: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        const contents = try file.readToEndAlloc(allocator, 32 * 1024);
        defer allocator.free(contents);
        break :map try parseInput(allocator, contents);
    };
    defer {
        for (map) |m| allocator.free(m);
        allocator.free(map);
    }
    var paths = Paths.init(allocator);
    try paths.put(.{
        .x = 1,
        .y = 0,
        .dir = .right,
        .rem = 9,
    }, map[0][1]);
    try paths.put(.{
        .x = 0,
        .y = 1,
        .dir = .down,
        .rem = 9,
    }, map[1][0]);
    defer paths.deinit();
    var walkers = Walker.init(allocator, &paths);
    defer walkers.deinit();
    try walkers.add(.{
        .x = 1,
        .y = 0,
        .dir = .right,
        .rem = 9,
    });
    try walkers.add(.{
        .x = 0,
        .y = 1,
        .dir = .down,
        .rem = 9,
    });
    const count = try walk(&walkers, &paths, map);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

const Walker = std.PriorityQueue(Data, *Paths, compareFn);

const Paths = std.AutoHashMap(Data, usize);

fn walk(walkers: *Walker, paths: *Paths, map: []const []const u8) !usize {
    while (walkers.removeOrNull()) |current| {
        const cost = paths.get(current) orelse return error.WalkFailed;
        if (current.y + 1 == map.len and current.x + 1 == map[map.len - 1].len and current.rem < 7) {
            return cost;
        }
        const directions: [4]?Data = .{
            if (current.x > 0 and current.dir != .right and
                ((current.dir == .left and current.rem > 0) or
                (current.dir != .left and current.rem < 7)))
                .{
                    .x = current.x - 1,
                    .y = current.y,
                    .dir = .left,
                    .rem = if (current.dir != .left) 9 else current.rem - 1,
                }
            else
                null,
            if (current.x + 1 < map[current.y].len and current.dir != .left and
                ((current.dir == .right and current.rem > 0) or
                (current.dir != .right and current.rem < 7)))
                .{
                    .x = current.x + 1,
                    .y = current.y,
                    .dir = .right,
                    .rem = if (current.dir != .right) 9 else current.rem - 1,
                }
            else
                null,
            if (current.y > 0 and current.dir != .down and
                ((current.dir == .up and current.rem > 0) or
                (current.dir != .up and current.rem < 7)))
                .{
                    .x = current.x,
                    .y = current.y - 1,
                    .dir = .up,
                    .rem = if (current.dir != .up) 9 else current.rem - 1,
                }
            else
                null,
            if (current.y + 1 < map.len and current.dir != .up and
                ((current.dir == .down and current.rem > 0) or
                (current.dir != .down and current.rem < 7)))
                .{
                    .x = current.x,
                    .y = current.y + 1,
                    .dir = .down,
                    .rem = if (current.dir != .down) 9 else current.rem - 1,
                }
            else
                null,
        };
        for (directions) |can_go_there| {
            if (can_go_there) |p| {
                if (paths.get(p)) |old_cost| {
                    if (cost + map[p.y][p.x] >= old_cost) continue;
                    try paths.put(p, cost + map[p.y][p.x]);
                    try walkers.add(p);
                } else {
                    try paths.put(p, cost + map[p.y][p.x]);
                    try walkers.add(p);
                }
            }
        }
    }
    return error.NotFound;
}

fn compareFn(context: *Paths, a: Data, b: Data) std.math.Order {
    const a_cost = context.get(a).?;
    const b_cost = context.get(b).?;
    if (a_cost < b_cost) return .lt;
    if (a_cost > b_cost) return .gt;
    return .eq;
}

const Direction = enum { up, down, left, right };

const Data = struct {
    x: usize,
    y: usize,
    dir: Direction,
    rem: u8,
};

fn eql(a: Data, b: Data) bool {
    return a.x == b.x and a.y == b.y and a.dir == b.dir and a.rem == b.rem;
}

fn parseInput(allocator: std.mem.Allocator, input: []const u8) ![]const []const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (list.items) |i| allocator.free(i);
        list.deinit();
    }
    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (tokenizer.next()) |line| {
        const parsed = try allocator.dupe(u8, line);
        errdefer allocator.free(parsed);
        for (parsed) |*char| {
            char.* -= '0';
        }
        try list.append(parsed);
    }
    return try list.toOwnedSlice();
}

test "parseInput" {
    const input =
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
    ;
    const parsed: []const []const u8 = &.{
        &.{ 2, 4, 1, 3, 4, 3, 2, 3, 1, 1, 3, 2, 3 },
        &.{ 3, 2, 1, 5, 4, 5, 3, 5, 3, 5, 6, 2, 3 },
        &.{ 3, 2, 5, 5, 2, 4, 5, 6, 5, 4, 2, 5, 4 },
        &.{ 3, 4, 4, 6, 5, 8, 5, 8, 4, 5, 4, 5, 2 },
        &.{ 4, 5, 4, 6, 6, 5, 7, 8, 6, 7, 5, 3, 6 },
        &.{ 1, 4, 3, 8, 5, 9, 8, 7, 9, 8, 4, 5, 4 },
        &.{ 4, 4, 5, 7, 8, 7, 6, 9, 8, 7, 7, 6, 6 },
        &.{ 3, 6, 3, 7, 8, 7, 7, 9, 7, 9, 6, 5, 3 },
        &.{ 4, 6, 5, 4, 9, 6, 7, 9, 8, 6, 8, 8, 7 },
        &.{ 4, 5, 6, 4, 6, 7, 9, 9, 8, 6, 4, 5, 3 },
        &.{ 1, 2, 2, 4, 6, 8, 6, 8, 6, 5, 5, 6, 3 },
        &.{ 2, 5, 4, 6, 5, 4, 8, 8, 8, 7, 7, 3, 5 },
        &.{ 4, 3, 2, 2, 6, 7, 4, 6, 5, 5, 5, 3, 3 },
    };
    const output = try parseInput(std.testing.allocator, input);
    defer {
        for (output) |o| std.testing.allocator.free(o);
        std.testing.allocator.free(output);
    }
    for (parsed, output) |expected, actual| {
        try std.testing.expectEqualStrings(expected, actual);
    }
}

test "walk map" {
    const map: []const []const u8 = &.{
        &.{ 2, 4, 1, 3, 4, 3, 2, 3, 1, 1, 3, 2, 3 },
        &.{ 3, 2, 1, 5, 4, 5, 3, 5, 3, 5, 6, 2, 3 },
        &.{ 3, 2, 5, 5, 2, 4, 5, 6, 5, 4, 2, 5, 4 },
        &.{ 3, 4, 4, 6, 5, 8, 5, 8, 4, 5, 4, 5, 2 },
        &.{ 4, 5, 4, 6, 6, 5, 7, 8, 6, 7, 5, 3, 6 },
        &.{ 1, 4, 3, 8, 5, 9, 8, 7, 9, 8, 4, 5, 4 },
        &.{ 4, 4, 5, 7, 8, 7, 6, 9, 8, 7, 7, 6, 6 },
        &.{ 3, 6, 3, 7, 8, 7, 7, 9, 7, 9, 6, 5, 3 },
        &.{ 4, 6, 5, 4, 9, 6, 7, 9, 8, 6, 8, 8, 7 },
        &.{ 4, 5, 6, 4, 6, 7, 9, 9, 8, 6, 4, 5, 3 },
        &.{ 1, 2, 2, 4, 6, 8, 6, 8, 6, 5, 5, 6, 3 },
        &.{ 2, 5, 4, 6, 5, 4, 8, 8, 8, 7, 7, 3, 5 },
        &.{ 4, 3, 2, 2, 6, 7, 4, 6, 5, 5, 5, 3, 3 },
    };
    const allocator = std.testing.allocator;
    var paths = Paths.init(allocator);
    defer paths.deinit();
    try paths.put(.{
        .x = 1,
        .y = 0,
        .dir = .right,
        .rem = 9,
    }, 4);
    try paths.put(.{
        .x = 0,
        .y = 1,
        .dir = .down,
        .rem = 9,
    }, 3);
    var walkers = Walker.init(allocator, &paths);
    defer walkers.deinit();
    try walkers.add(.{
        .x = 1,
        .y = 0,
        .dir = .right,
        .rem = 9,
    });
    try walkers.add(.{
        .x = 0,
        .y = 1,
        .dir = .down,
        .rem = 9,
    });
    const count = try walk(&walkers, &paths, map);
    try std.testing.expectEqual(@as(usize, 94), count);
}

test "second walk" {
    const map: []const []const u8 = &.{
        &.{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
        &.{ 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 1 },
        &.{ 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 1 },
        &.{ 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 1 },
        &.{ 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 1 },
    };
    const allocator = std.testing.allocator;
    var paths = Paths.init(allocator);
    defer paths.deinit();
    try paths.put(.{
        .x = 1,
        .y = 0,
        .dir = .right,
        .rem = 9,
    }, 1);
    try paths.put(.{
        .x = 0,
        .y = 1,
        .dir = .down,
        .rem = 9,
    }, 9);
    var walkers = Walker.init(allocator, &paths);
    defer walkers.deinit();
    try walkers.add(.{
        .x = 1,
        .y = 0,
        .dir = .right,
        .rem = 9,
    });
    try walkers.add(.{
        .x = 0,
        .y = 1,
        .dir = .down,
        .rem = 9,
    });
    const count = try walk(&walkers, &paths, map);
    try std.testing.expectEqual(@as(usize, 71), count);
}
