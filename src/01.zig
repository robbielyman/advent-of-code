const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    const allocator = arena.allocator();
    const filename = try parseArgs(allocator);
    const reader = try getReaderFromFile(filename);
    allocator.free(filename);
    var count: u64 = 0;
    var done = false;
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    while (!done) {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        count += processLine(&buffer) catch |err| blk: {
            if (err == error.NoDigits) break :blk 0 else return err;
        };
    }
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn parseArgs(allocator: std.mem.Allocator) ![:0]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    const process_name = args.next().?;
    allocator.free(process_name);
    const filename = args.next() orelse {
        std.debug.print("call with a filename as the first argument!", .{});
        std.process.exit(1);
    };
    while (args.next()) |arg| {
        std.debug.print("ignoring arg {s}", .{arg});
        allocator.free(arg);
    }
    return filename;
}

fn getReaderFromFile(filename: [:0]const u8) !std.fs.File.Reader {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    return file.reader();
}

fn processLine(buffer: *std.ArrayList(u8)) !u64 {
    const line = buffer.items;
    defer buffer.clearRetainingCapacity();
    var digits: [2]u8 = undefined;
    var first_done = false;
    var last_done = false;
    for (line, 1..) |char, i| {
        if (!first_done) {
            if (isDigit(char)) |d| {
                digits[0] = d;
                first_done = true;
            }
        }
        if (!last_done) {
            if (isDigit(line[line.len - i])) |d| {
                digits[1] = d;
                last_done = true;
            }
        }
        if (first_done and last_done) break;
    } else return error.NoDigits;
    return try std.fmt.parseUnsigned(u64, &digits, 10);
}

fn isDigit(char: u8) ?u8 {
    switch (char) {
        '0'...'9' => return char,
        else => return null,
    }
}
