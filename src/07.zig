const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const filename = try processArgs(allocator);
    var reader = try getReaderFromFilename(filename);
    allocator.free(filename);
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var done = false;
    var count: usize = 0;
    while (!done) {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true;
        };
        count += processLine(buffer.items) catch |err| blk: {
            if (err == error.ParseFailed) break :blk 0 else return err;
        };
        buffer.clearRetainingCapacity();
    }
    reader.context.close();
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn processArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse {
        std.debug.print("pass a filename as the first argument!\n", .{});
        std.process.exit(1);
    };
    while (args.next()) |arg| {
        std.debug.print("ignoring argument {s}\n", .{arg});
        allocator.free(arg);
    }
    args.deinit();
    return try allocator.dupe(u8, filename);
}

fn getReaderFromFilename(filename: []const u8) !std.fs.File.Reader {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    return file.reader();
}

fn processLine(line: []const u8) !usize {
    var iterator = std.mem.tokenizeAny(u8, line, ":|");
    _ = iterator.next();
    const winning_numbers = iterator.next() orelse return error.ParseFailed;
    const got_slice = iterator.next() orelse return error.ParseFailed;
    var found = false;
    var count: usize = 1;
    var buffer: [128]usize = undefined;
    const received_numbers = received_numbers: {
        var idx: usize = 0;
        var tokenizer = std.mem.tokenizeScalar(u8, got_slice, ' ');
        while (tokenizer.next()) |token| {
            buffer[idx] = try std.fmt.parseUnsigned(usize, token, 10);
            idx += 1;
        }
        break :received_numbers buffer[0..idx];
    };
    var tokenizer = std.mem.tokenizeScalar(u8, winning_numbers, ' ');
    while (tokenizer.next()) |token| {
        const winning_number = try std.fmt.parseUnsigned(usize, token, 10);
        if (std.mem.indexOfScalar(usize, received_numbers, winning_number)) |_| {
            if (!found) {
                found = true;
                continue;
            }
            count *= 2;
        }
    }
    return count;
}

test "processLine" {
    const data: []const []const u8 = &.{
        "Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53",
        "Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19",
        "Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1",
        "Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83",
        "Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36",
        "Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11",
    };
    const expected: []const usize = &.{ 8, 2, 2, 1, 0, 0 };
    for (data, expected) |line, value| {
        try std.testing.expectEqual(value, try processLine(line));
    }
}
