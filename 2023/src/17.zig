const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = try parseArgs(allocator);
    const reader = try getReaderFromFilename(filename);
    allocator.free(filename);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var done = false;
    var count: i32 = 0;
    while (!done) {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        const numbers = try tokenizeLine(allocator, buffer.items);
        count += try recurseDifferences(allocator, numbers);
        allocator.free(numbers);
        buffer.clearRetainingCapacity();
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

fn tokenizeLine(allocator: std.mem.Allocator, line: []const u8) ![]const i32 {
    var tokens = try std.ArrayList(i32).initCapacity(allocator, line.len);
    defer tokens.deinit();
    var tokenizer = std.mem.tokenizeScalar(u8, line, ' ');
    while (tokenizer.next()) |token| {
        const number = try std.fmt.parseInt(i32, token, 10);
        try tokens.append(number);
    }
    return try tokens.toOwnedSlice();
}

fn recurseDifferences(allocator: std.mem.Allocator, numbers: []const i32) !i32 {
    if (numbers.len == 0) return 0;
    const new_numbers = try allocator.alloc(i32, numbers.len -| 1);
    defer allocator.free(new_numbers);
    for (new_numbers, 0..) |*num, i| {
        num.* = numbers[i + 1] - numbers[i];
    }
    const done = blk: {
        for (new_numbers) |number| {
            if (number != 0) break :blk false;
        }
        break :blk true;
    };
    if (done) return numbers[numbers.len -| 1];
    return numbers[numbers.len - 1] + try recurseDifferences(allocator, new_numbers);
}

test "recurseDifferences" {
    const input: []const []const u8 = &.{
        "0 3 6 9 12 15",
        "1 3 6 10 15 21",
        "10 13 16 21 30 45",
    };
    const output: []const i32 = &.{ 18, 28, 68 };
    const allocator = std.testing.allocator;
    for (input, output) |line, expected| {
        const numbers = try tokenizeLine(allocator, line);
        defer allocator.free(numbers);
        const actual = try recurseDifferences(allocator, numbers);
        try std.testing.expectEqual(expected, actual);
    }
}
