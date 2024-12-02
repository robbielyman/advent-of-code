const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const map = map: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :map try getInput(filename, allocator);
    };
    defer {
        for (map) |l| allocator.free(l);
        allocator.free(map);
    }

    const starting = try allocator.dupe([2]usize, &.{
        .{ 1, 0 }, .{ 1, 1 },
    });
    var queue = Queue.init(allocator, {});
    defer queue.deinit();
    try queue.add(starting);
    var count: usize = 0;
    while (queue.removeOrNull()) |history| {
        defer allocator.free(history);
        if (history[history.len - 1][1] == map.len - 1) {
            count = @max(count, history.len - 1);
        } else {
            const slice = try takeStep(map, history, allocator);
            defer allocator.free(slice);
            try queue.addSlice(slice);
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn getInput(filename: []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    const reader = file.reader();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var lines = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (lines.items) |i| allocator.free(i);
        lines.deinit();
    }
    var done = false;
    while (!done) {
        defer buffer.clearRetainingCapacity();
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        if (buffer.items.len > 0) {
            const line = try buffer.toOwnedSlice();
            try lines.append(line);
        }
    }
    return try lines.toOwnedSlice();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.NoFilename;
    return try allocator.dupe(u8, filename);
}

fn takeStep(
    map: []const []const u8,
    history: []const [2]usize,
    allocator: std.mem.Allocator,
) ![]const []const [2]usize {
    const last = history[history.len - 1];
    const next: [4][2]usize = .{
        .{ last[0] - 1, last[1] },
        .{ last[0] + 1, last[1] },
        .{ last[0], last[1] - 1 },
        .{ last[0], last[1] + 1 },
    };
    var list = std.ArrayList([]const [2]usize).init(allocator);
    for (next, 0..) |coord, i| {
        if (map[coord[1]][coord[0]] == '#') continue;
        switch (map[last[1]][last[0]]) {
            '<' => if (i != 0) continue,
            '>' => if (i != 1) continue,
            '^' => if (i != 2) continue,
            'v' => if (i != 3) continue,
            else => {},
        }
        for (history) |val| {
            if (val[0] == coord[0] and val[1] == coord[1]) break;
        } else {
            const new = try allocator.alloc([2]usize, history.len + 1);
            @memcpy(new[0..history.len], history);
            new[history.len] = coord;
            try list.append(new);
        }
    }
    return try list.toOwnedSlice();
}

const Queue = std.PriorityQueue([]const [2]usize, void, compareFn);

fn compareFn(context: void, a: []const [2]usize, b: []const [2]usize) std.math.Order {
    _ = context;
    if (a.len > b.len) return .lt;
    if (a.len < b.len) return .gt;
    return .eq;
}

test "end to end" {
    const input =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
    ;
    const allocator = std.testing.allocator;
    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    var map = std.ArrayList([]const u8).init(allocator);
    defer map.deinit();
    while (tokenizer.next()) |line| {
        try map.append(line);
    }
    const starting = try allocator.dupe([2]usize, &.{
        .{ 1, 0 }, .{ 1, 1 },
    });
    var queue = Queue.init(allocator, {});
    defer queue.deinit();
    try queue.add(starting);
    var count: usize = 0;
    while (queue.removeOrNull()) |history| {
        defer allocator.free(history);
        if (history[history.len - 1][1] == map.items.len - 1) {
            count = @max(count, history.len - 1);
        } else {
            const slice = try takeStep(map.items, history, allocator);
            defer {
                allocator.free(slice);
            }
            try queue.addSlice(slice);
        }
    }
    try std.testing.expectEqual(@as(usize, 94), count);
}
