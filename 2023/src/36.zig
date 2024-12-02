const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const reader = reader: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :reader try readerFromFilename(filename);
    };
    defer reader.context.close();
    var done = false;
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var x: i64 = 0;
    var y: i64 = 0;
    var area: i64 = 0;
    var perimeter: i64 = 0;
    while (!done) {
        defer buffer.clearRetainingCapacity();
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        if (buffer.items.len > 0) try shoelace(buffer.items, &x, &y, &area, &perimeter);
    }
    const count: i128 = @divExact(@abs(area) + @as(i128,perimeter), 2) + 1;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn readerFromFilename(filename: []const u8) !std.fs.File.Reader {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    return file.reader();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.NoFilename;
    return try allocator.dupe(u8, filename);
}

test "parseInput" {
    const input: []const []const u8 = &.{
        "R 6 (#70c710)",
        "D 5 (#0dc571)",
        "L 2 (#5713f0)",
        "D 2 (#d2c081)",
        "R 2 (#59c680)",
        "D 2 (#411b91)",
        "L 5 (#8ceee2)",
        "U 2 (#caa173)",
        "L 1 (#1b58a2)",
        "U 2 (#caa171)",
        "R 2 (#7807d2)",
        "U 3 (#a77fa3)",
        "L 2 (#015232)",
        "U 2 (#7a21e3)",
    };
    const coords: []const [2]i64 = &.{
        .{ 461937, 0 },
        .{ 461937, -56407 },
        .{ 818608, -56407 },
        .{ 818608, -919647 },
        .{ 1186328, -919647 },
        .{ 1186328, -1186328 },
        .{ 609066, -1186328 },
        .{ 609066, -356353 },
        .{ 497056, -356353 },
        .{ 497056, -1186328 },
        .{ 5411, -1186328 },
        .{ 5411, -500254 },
        .{ 0, -500254 },
        .{ 0, 0 },
    };
    var x: i64 = 0;
    var y: i64 = 0;
    var interior: i64 = 0;
    var perimeter: i64 = 0;
    for (input, coords) |line, coord| {
        try shoelace(line, &x, &y, &interior, &perimeter);
        try std.testing.expectEqual(coord[0], x);
        try std.testing.expectEqual(coord[1], y);
    }
    const count = @divExact(interior + perimeter, 2) + 1;
    try std.testing.expectEqual(@as(i64, 952408144115), count);
}

fn shoelace(line: []const u8, x: *i64, y: *i64, area: *i64, perimeter: *i64) !void {
    const new_x, const new_y = coords: {
        const idx = std.mem.indexOfScalar(u8, line, '#') orelse return error.ParseFailed;
        const number = try std.fmt.parseUnsigned(i64, line[idx+1..][0..5], 16);
        perimeter.* += number;
        switch (line[idx+1..][5]) {
            '0' => break :coords .{ x.* + number, y.* },
            '2' => break :coords .{ x.* - number, y.* },
            '3' => break :coords .{ x.*, y.* + number },
            '1' => break :coords .{ x.*, y.* - number },
            else => unreachable,
        }
    };
    area.* += (new_y + y.*) * (new_x - x.*);
    y.* = new_y;
    x.* = new_x;
}
