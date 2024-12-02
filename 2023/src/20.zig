const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = try parseArgs(allocator);
    const contents = try getContentsOfFile(allocator, filename);
    defer {
        for (contents) |line| allocator.free(line);
        allocator.free(contents);
    }
    allocator.free(filename);
    var x: usize = undefined;
    var y: usize = undefined;
    const map = try buildMap(allocator, contents, &x, &y);
    defer {
        for (map) |row| allocator.free(row);
        allocator.free(map);
    }
    try replaceStart(x, y, contents);
    try findLoop(x, y, contents, map);
    var count: usize = 0;
    for (contents, map) |row, loop| {
        count += countInsideRow(row, loop);
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.NoFilenameGiven;
    return try allocator.dupe(u8, filename);
}

fn getContentsOfFile(allocator: std.mem.Allocator, filename: []const u8) ![]const []u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    const reader = file.reader();
    var scratch = std.ArrayList(u8).init(allocator);
    var lines = std.ArrayList([]u8).init(allocator);
    var done = false;
    while (!done) {
        reader.streamUntilDelimiter(scratch.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true;
        };
        try lines.append(try scratch.toOwnedSlice());
    }
    return try lines.toOwnedSlice();
}

fn buildMap(
    allocator: std.mem.Allocator,
    input: []const []const u8,
    start_x: *usize,
    start_y: *usize,
) ![]const []bool {
    const map = try allocator.alloc([]bool, input.len);
    var done = false;
    for (input, map, 0..) |line, *tiles, y| {
        tiles.* = try allocator.alloc(bool, line.len);
        @memset(tiles.*, false);
        if (!done) {
            for (line, tiles.*, 0..) |pipe, *tile, x| {
                if (pipe == 'S') {
                    tile.* = true;
                    start_x.* = x;
                    start_y.* = y;
                    done = true;
                    break;
                }
            }
        }
    }
    return map;
}

fn replaceStart(start_x: usize, start_y: usize, map: []const []u8) !void {
    if (map[start_y][start_x] != 'S')
        return error.WalkFailed;
    const new_indices: [4][2]usize = .{
        .{ start_x -| 1, start_y },
        .{ start_x + 1, start_y },
        .{ start_x, start_y -| 1 },
        .{ start_x, start_y + 1 },
    };
    const haystacks: []const []const u8 = &.{
        "-LF", "-J7", "|F7", "|LJ",
    };
    const new_start = "-J7LF|";
    const indices: [2]usize = find: {
        var find: [2]usize = undefined;
        var idx: usize = 0;
        for (&new_indices, haystacks, 0..) |indices, haystack, i| {
            const pipe = map[indices[1]][indices[0]];
            if (std.mem.indexOfScalar(u8, haystack, pipe)) |_| {
                find[idx] = i;
                idx += 1;
                if (idx == 2) break;
            }
        }
        break :find find;
    };
    map[start_y][start_x] = new: {
        switch (indices[0]) {
            0 => if (indices[1] > 0 and indices[1] < 4) break :new new_start[indices[1]],
            1 => if (indices[1] > 1 and indices[1] < 4) break :new new_start[indices[1] + 1],
            2 => if (indices[1] == 3) break :new new_start[5],
            else => return error.WalkFailed,
        }
        return error.WalkFailed;
    };
}

fn findLoop(start_x: usize, start_y: usize, tiles: []const []const u8, map: []const []bool) !void {
    const Direction = enum { North, East, South, West };
    var x = start_x;
    var y = start_y;
    var done = false;
    var from: Direction = .North;
    while (!done) {
        const char = tiles[y][x];
        switch (char) {
            '-' => if (from == .East) {
                x = x -| 1;
            } else {
                x += 1;
                from = .West;
            },
            '|' => if (from == .North) {
                y += 1;
            } else {
                y -= 1;
                from = .South;
            },
            'J' => if (from == .North) {
                x = x -| 1;
                from = .East;
            } else {
                y = y -| 1;
                from = .South;
            },
            '7' => if (from == .West) {
                y += 1;
                from = .North;
            } else {
                x = x -| 1;
                from = .East;
            },
            'L' => if (from == .North) {
                x += 1;
                from = .West;
            } else {
                y = y -| 1;
                from = .South;
            },
            'F' => if (from == .East) {
                y += 1;
                from = .North;
            } else {
                x += 1;
                from = .West;
            },
            else => return error.WalkFailed,
        }
        done = map[y][x];
        map[y][x] = true;
    }
}

fn countInsideRow(row: []const u8, loop: []const bool) usize {
    var count: usize = 0;
    var inside = false;
    var last: u8 = 0;
    for (row, loop) |char, is_loop| {
        if (!is_loop) {
            if (inside) count += 1;
        } else {
            if (char == '|') inside = !inside;
            if (char == 'L' or char == 'F') last = char;
            if (char == '7' and last == 'L') inside = !inside;
            if (char == 'J' and last == 'F') inside = !inside;
            if (char == '7' or char == 'J') last = 0;
        }
    }
    return count;
}

test "buildMap" {
    const input: []const []const u8 = &.{
        ".F----7F7F7F7F-7....",
        ".|F--7||||||||FJ....",
        ".||.FJ||||||||L7....",
        "FJL7L7LJLJ||LJ.L-7..",
        "L--J.L7...LJS7F-7L7.",
        "....F-J..F7FJ|L7L7L7",
        "....L7.F7||L7|.L7L7|",
        ".....|FJLJ|FJ|F7|.LJ",
        "....FJL-7.||.||||...",
        "....L---J.LJ.LJLJ...",
    };
    var x: usize = undefined;
    var y: usize = undefined;
    const allocator = std.testing.allocator;
    const map = try allocator.alloc([]u8, input.len);
    defer allocator.free(map);
    for (input, map) |line, *new_line| {
        new_line.* = try allocator.alloc(u8, line.len);
        @memcpy(new_line.*, line);
    }
    defer for (map) |line| allocator.free(line);
    const loop = try buildMap(allocator, input, &x, &y);
    defer {
        for (loop) |line| allocator.free(line);
        allocator.free(loop);
    }
    try replaceStart(x, y, map);
    try findLoop(x, y, map, loop);
    var count: usize = 0;
    for (map, loop) |row, loop_row| {
        count += countInsideRow(row, loop_row);
    }
    try std.testing.expectEqual(@as(usize, 8), count);
}
