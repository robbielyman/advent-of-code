const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const times, const distances = blk: {
        const filename = try parseArgs(allocator);
        var reader = try getReaderFromFilename(filename);
        defer reader.context.close();
        allocator.free(filename);
        
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        var nums_buf = std.ArrayList(usize).init(allocator);
        defer nums_buf.deinit();
        
        try reader.streamUntilDelimiter(buffer.writer(), '\n', null);
        try getNumbersFromLine(buffer.items, &nums_buf);
        const times = try nums_buf.toOwnedSlice();
        buffer.clearRetainingCapacity();
        nums_buf.clearRetainingCapacity();

        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err != error.EndOfStream) return err;
        };
        try getNumbersFromLine(buffer.items, &nums_buf);
        const distances = try nums_buf.toOwnedSlice();
        break :blk .{ times, distances };
    };

    var count: usize = 1;
    for (times, distances) |time, distance| {
        count *= numberOfWinningMoves(time, distance);
    }
    allocator.free(times);
    allocator.free(distances);

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
    const filename = args.next() orelse {
        std.debug.print("pass the filename as the first argument!", .{});
        std.process.exit(1);
    };
    return try allocator.dupe(u8, filename);
}

fn getReaderFromFilename(filename: []const u8) !std.fs.File.Reader {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    return file.reader();
}

fn getNumbersFromLine(line: []const u8, buffer: *std.ArrayList(usize)) !void {
    var iterator = std.mem.tokenizeScalar(u8, line, ' ');
    _ = iterator.next();
    while (iterator.next()) |chunk| {
        const number = try std.fmt.parseUnsigned(usize, chunk, 10);
        try buffer.append(number);
    }
}

fn numberOfWinningMoves(time: usize, distance: usize) usize {
    var count: usize = 0;
    for (0..time) |i| {
        const time_remaining = time - i;
        if (time_remaining * i > distance) count += 1;
    }
    return count;
}

test "numberOfWinningMoves" {
    const times: []const usize = &.{ 7, 15, 30 };
    const distances: []const usize = &.{9,40, 200};
    const expected: []const usize = &.{ 4, 8, 9 };
    var count: usize = 1;
    var actual_count: usize = 1;
    for (times, distances, expected) |time, distance, value| {
        const got = numberOfWinningMoves(time, distance);
        try std.testing.expectEqual(value, got);
        count *= value;
        actual_count *= got;
    }
    try std.testing.expectEqual(count, actual_count);
}

test "getNumbersFromLine" {
    const lines: []const []const u8 = &.{
        "Time:      7  15   30",
        "Distance:  9  40  200",
    };
    const numbers: []const []const usize = &.{
        &.{ 7, 15, 30 },
        &.{9, 40, 200},
    };
    var nums_buf = std.ArrayList(usize).init(std.testing.allocator);
    defer nums_buf.deinit();
    for (lines, numbers) |line, expected| {
        try getNumbersFromLine(line, &nums_buf);
        try std.testing.expectEqualSlices(usize, expected, nums_buf.items);
        nums_buf.clearRetainingCapacity();
    }
}
