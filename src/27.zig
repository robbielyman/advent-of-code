const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = input: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        const input = try getInput(allocator, filename);
        break :input input;
    };
    defer {
        for (input) |i| allocator.free(i);
        allocator.free(input);
    }
    const transposed = try transpose(allocator, input);
    defer {
        for (transposed) |i| allocator.free(i);
        allocator.free(transposed);
    }
    for (transposed) |row| rollLeft(row);
    const output = try transpose(allocator, transposed);
    defer {
        for (output) |i| allocator.free(i);
        allocator.free(output);
    }
    const count = countWeight(output);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn getInput(allocator: std.mem.Allocator, filename: []const u8) ![]const []const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    const reader = file.reader();
    var lines = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (lines.items) |value| allocator.free(value);
        lines.deinit();
    }
    var scratch = std.ArrayList(u8).init(allocator);
    errdefer scratch.deinit();
    var done = false;
    while (!done) {
        reader.streamUntilDelimiter(scratch.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        const line = try scratch.toOwnedSlice();
        if (line.len == 0) {
            done = true;
            allocator.free(line);
        } else {
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

fn countWeight(input: []const []const u8) usize {
    var count: usize = 0;
    for (input, 0..) |line, i| {
        for (line) |char| {
            if (char == 'O') count += input.len - i;
        }
    }
    return count;
}

test "countWeight" {
    const input: []const []const u8 = &.{
        "OOOO.#.O..",
        "OO..#....#",
        "OO..O##..O",
        "O..#.OO...",
        "........#.",
        "..#....#.#",
        "..O..#.O.O",
        "..O.......",
        "#....###..",
        "#....#....",
    };
    try std.testing.expectEqual(@as(usize, 136), countWeight(input));
}

fn transpose(allocator: std.mem.Allocator, input: []const []const u8) ![]const []u8 {
    for (input) |line| {
        if (line.len != input[0].len) return error.InputNotRectangular;
    }
    const output = try allocator.alloc([]u8, input[0].len);
    for (output, 0..) |*column, i| {
        const new_col = try allocator.alloc(u8, input.len);
        for (input, new_col) |line, *val| {
            val.* = line[i];
        }
        column.* = new_col;
    }
    return output;
}

fn rollLeft(buffer: []u8) void {
    var pos: usize = 0;
    var next = std.mem.indexOfScalarPos(u8, buffer, pos + 1, '#') orelse buffer.len;
    while (pos < buffer.len) {
        std.mem.sort(u8, buffer[pos..next], {}, lessThanFn);
        pos = next;
        next = std.mem.indexOfScalarPos(u8, buffer, pos + 1, '#') orelse buffer.len;
    }
}

fn lessThanFn(context: void, a: u8, b: u8) bool {
    _ = context;
    switch (a) {
        '.' => return false,
        'O' => return (b != 'O' and b != '#'),
        '#' => return false,
        else => unreachable,
    }
}

test "rollLeft" {
    const input: []const u8 = ".O.##..O.#.#";
    const output: []const u8 = "O..##O...#.#";
    const allocator = std.testing.allocator;
    const row = try allocator.dupe(u8, input);
    defer allocator.free(row);
    rollLeft(row);
    try std.testing.expectEqualStrings(output, row);
}

test "twoTransposes" {
    const input: []const []const u8 = &.{
        "O....#....",
        "O.OO#....#",
        ".....##...",
        "OO.#O....O",
        ".O.....O#.",
        "O.#..O.#.#",
        "..O..#O..O",
        ".......O..",
        "#....###..",
        "#OO..#....",
    };
    const output: []const []const u8 = &.{
        "OOOO.#.O..",
        "OO..#....#",
        "OO..O##..O",
        "O..#.OO...",
        "........#.",
        "..#....#.#",
        "..O..#.O.O",
        "..O.......",
        "#....###..",
        "#....#....",
    };
    const allocator = std.testing.allocator;
    const transposed = try transpose(allocator, input);
    defer {
        for (transposed) |t| allocator.free(t);
        allocator.free(transposed);
    }
    for (transposed) |line| rollLeft(line);
    const received = try transpose(allocator, transposed);
    defer {
        for (received) |r| allocator.free(r);
        allocator.free(received);
    }
    for (received, output) |got, expected| {
        try std.testing.expectEqualStrings(expected, got);
    }
}
