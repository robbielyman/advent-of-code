const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = try parseArgs(allocator);
    errdefer allocator.free(filename);
    const map = try getContentsOfFile(allocator, filename);
    defer {
        for (map) |line| allocator.free(line);
        allocator.free(map);
    }
    allocator.free(filename);

    const rows = try expandRows(allocator, map);
    defer allocator.free(rows);
    const cols = try expandColumns(allocator, map);
    defer allocator.free(cols);
    const gals = try enumerateGalaxies(allocator, map);
    defer allocator.free(gals);

    var count: usize = 0;
    for (gals, 1..) |a, i| {
        if (i == gals.len) break;
        for (gals[i..]) |b| {
            const coords = expandedCoordinates(rows, cols, a, b);
            count += manhattanDistance(coords[0], coords[1]);
        }
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
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

fn getContentsOfFile(allocator: std.mem.Allocator, filename: []const u8) ![]const []const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    const reader = file.reader();

    var lines = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (lines.items) |item| allocator.free(item);
        lines.deinit();
    }
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();
    var done = false;

    while (!done) {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        if (buffer.items.len > 0)
            try lines.append(try buffer.toOwnedSlice())
        else
            buffer.clearAndFree();
    }
    return try lines.toOwnedSlice();
}

fn expandRows(allocator: std.mem.Allocator, map: []const []const u8) ![]const usize {
    var list = std.ArrayList(usize).init(allocator);
    for (map, 0..) |row, i| {
        if (std.mem.indexOfScalar(u8, row, '#') == null)
            try list.append(i);
    }
    return try list.toOwnedSlice();
}

fn expandColumns(allocator: std.mem.Allocator, map: []const []const u8) ![]const usize {
    var list = std.ArrayList(usize).init(allocator);
    for (0..map[0].len) |i| {
        for (map) |row| {
            if (row[i] == '#') break;
        } else try list.append(i);
    }
    return try list.toOwnedSlice();
}

fn enumerateGalaxies(allocator: std.mem.Allocator, map: []const []const u8) ![]const [2]usize {
    var list = std.ArrayList([2]usize).init(allocator);
    for (map, 0..) |row, i| {
        for (row, 0..) |item, j| {
            if (item != '#') continue;
            try list.append(.{ i, j });
        }
    }
    return list.toOwnedSlice();
}

fn manhattanDistance(a: [2]usize, b: [2]usize) usize {
    var distance: usize = 0;
    distance += if (b[0] >= a[0]) b[0] - a[0] else a[0] - b[0];
    distance += if (b[1] >= a[1]) b[1] - a[1] else a[1] - b[1];
    return distance;
}

fn expandedCoordinates(rows: []const usize, cols: []const usize, a: [2]usize, b: [2]usize) [2][2]usize {
    const row_offset = row_offset: {
        var a_offset: ?usize = null;
        var b_offset: ?usize = null;
        for (rows, 0..) |val, i| {
            if (a_offset == null and val > a[0]) a_offset = i;
            if (b_offset == null and val > b[0]) b_offset = i;
            if (a_offset != null and b_offset != null) break;
        } else {
            if (a_offset == null) a_offset = rows.len;
            if (b_offset == null) b_offset = rows.len;
        }
        break :row_offset if (b_offset.? > a_offset.?)
            b_offset.? - a_offset.?
        else
            a_offset.? - b_offset.?;
    };
    const col_offset = col_offset: {
        var a_offset: ?usize = null;
        var b_offset: ?usize = null;
        for (cols, 0..) |val, i| {
            if (a_offset == null and val > a[1]) a_offset = i;
            if (b_offset == null and val > b[1]) b_offset = i;
            if (a_offset != null and b_offset != null) break;
        } else {
            if (a_offset == null) a_offset = cols.len;
            if (b_offset == null) b_offset = cols.len;
        }
        break :col_offset if (b_offset.? > a_offset.?)
            b_offset.? - a_offset.?
        else
            a_offset.? - b_offset.?;
    };
    if (b[0] > a[0]) {
        if (b[1] > a[1])
            return .{
                .{ a[0], a[1] },
                .{ b[0] + row_offset, b[1] + col_offset },
            }
        else
            return .{
                .{ a[0], a[1] + col_offset },
                .{ b[0] + row_offset, b[1] },
            };
    } else {
        if (b[1] > a[1])
            return .{
                .{ a[0] + row_offset, a[1] },
                .{ b[0], b[1] + col_offset },
            }
        else
            return .{
                .{ a[0] + row_offset, a[1] + col_offset },
                .{ b[0], b[1] },
            };
    }
}

test "manhattanDistance and expandedCoordinates" {
    const galaxies: []const [2]usize = &.{
        .{ 0, 3 }, .{ 1, 7 }, .{ 2, 0 },
        .{ 4, 6 }, .{ 5, 1 }, .{ 6, 9 },
        .{ 8, 7 }, .{ 9, 0 }, .{ 9, 4 },
    };
    const cols: []const usize = &.{ 2, 5, 8 };
    const rows: []const usize = &.{ 3, 7 };
    const expected: [2][2]usize = .{
        .{ 0, 3 }, .{ 1, 8 },
    };
    const new_coords = expandedCoordinates(rows, cols, galaxies[0], galaxies[1]);
    try std.testing.expectEqual(expected, new_coords);

    const expanded: []const [2][2]usize = &.{
        expandedCoordinates(rows, cols, galaxies[0], galaxies[6]),
        expandedCoordinates(rows, cols, galaxies[2], galaxies[5]),
        expandedCoordinates(rows, cols, galaxies[7], galaxies[8]),
    };
    const expected_distances: []const usize = &.{
        15, 17, 5,
    };
    for (expanded, expected_distances) |coords, distance| {
        try std.testing.expectEqual(distance, manhattanDistance(coords[0], coords[1]));
    }

    var count: usize = 0;
    for (galaxies, 1..) |a, i| {
        if (i == galaxies.len) break;
        for (galaxies[i..]) |b| {
            const expanded_coords = expandedCoordinates(rows, cols, a, b);
            count += manhattanDistance(expanded_coords[0], expanded_coords[1]);
        }
    }
    try std.testing.expectEqual(@as(usize, 374), count);
}

test "enumerateGalaxies" {
    const input: []const []const u8 = &.{
        "...#......",
        ".......#..",
        "#.........",
        "..........",
        "......#...",
        ".#........",
        ".........#",
        "..........",
        ".......#..",
        "#...#.....",
    };
    const expected: []const [2]usize = &.{
        .{ 0, 3 }, .{ 1, 7 }, .{ 2, 0 },
        .{ 4, 6 }, .{ 5, 1 }, .{ 6, 9 },
        .{ 8, 7 }, .{ 9, 0 }, .{ 9, 4 },
    };
    const allocator = std.testing.allocator;
    const indices = try enumerateGalaxies(allocator, input);
    defer allocator.free(indices);
    try std.testing.expectEqualSlices([2]usize, expected, indices);
}

test "expandRows and expandColumns" {
    const input: []const []const u8 = &.{
        "...#......",
        ".......#..",
        "#.........",
        "..........",
        "......#...",
        ".#........",
        ".........#",
        "..........",
        ".......#..",
        "#...#.....",
    };
    const expected_cols: []const usize = &.{ 2, 5, 8 };
    const expected_rows: []const usize = &.{ 3, 7 };
    const allocator = std.testing.allocator;
    const expanded_rows = try expandRows(allocator, input);
    defer allocator.free(expanded_rows);
    const expanded_cols = try expandColumns(allocator, input);
    defer allocator.free(expanded_cols);
    try std.testing.expectEqualSlices(usize, expected_rows, expanded_rows);
    try std.testing.expectEqualSlices(usize, expected_cols, expanded_cols);
}
