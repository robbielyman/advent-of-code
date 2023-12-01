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
    const needles: []const []const u8 = &.{
        "0",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "zero",
        "one",
        "two",
        "three",
        "four",
        "five",
        "six",
        "seven",
        "eight",
        "nine",
    };
    const line = buffer.items;
    defer buffer.clearRetainingCapacity();

    const first: u8, const last: u8 = blk: {
        var firsts: [20]i128 = undefined;
        var lasts: [20]i128 = undefined;
        for (needles, &firsts, &lasts) |needle, *first, *last| {
            first.* = std.mem.indexOf(u8, line, needle) orelse std.math.maxInt(i128);
            last.* = std.mem.lastIndexOf(u8, line, needle) orelse -1;
        }
        const first = std.mem.indexOfMin(i128, &firsts);
        const last = std.mem.indexOfMax(i128, &lasts);
        break :blk .{ @intCast(first % 10), @intCast(last % 10) };
    };
    var scratch: [2]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&scratch);
    const slice = try std.fmt.allocPrint(fba.allocator(), "{d}{d}", .{ first, last});
    return try std.fmt.parseUnsigned(u8, slice, 10);
}
