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
        
        try reader.streamUntilDelimiter(buffer.writer(), '\n', null);
        const times = try getNumberFromLine(buffer.items, allocator);
        buffer.clearRetainingCapacity();

        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err != error.EndOfStream) return err;
        };
        const distances = try getNumberFromLine(buffer.items, allocator);
        break :blk .{ times, distances };
    };

    var count = numberOfWinningMoves(times, distances);

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

fn getNumberFromLine(line: []const u8, allocator: std.mem.Allocator) !usize {
    var iterator = std.mem.tokenizeScalar(u8, line, ' ');
    var buffer: [4][]const u8 = undefined;
    var idx: usize = 0;
    _ = iterator.next();
    while (iterator.next()) |chunk| : (idx += 1) {
        buffer[idx] = chunk;
    }
    const str = try std.mem.join(allocator, "", buffer[0..idx]);
    defer allocator.free(str);
    return try std.fmt.parseUnsigned(usize, str, 10);
}

fn numberOfWinningMoves(time: usize, distance: usize) usize {
    const first_win, const last_win = wins: {
        var held_time: usize = 0;
        var first: ?usize = null;
        var last: ?usize = null;
        while (last == null and first == null) : (held_time += 1) {
            if (first == null and held_time * (time - held_time) > distance) {
                first = held_time;
            }
            if (last == null and (time - held_time) * (held_time) > distance) {
                last = time - held_time + 1;
            }
        }
        break :wins .{ first orelse 0, last orelse 0 };
    };
    const number_of_wins: i65 = @as(i65, last_win) - first_win;
    return @max(number_of_wins, 0);
}

test "numberOfWinningMoves" {
    const times: usize = 71530;
    const distances:usize = 940200;
    const expected: usize = 71503;
    const got = numberOfWinningMoves(times, distances);
    try std.testing.expectEqual(expected, got);
}

test "getNumberFromLine" {
    const lines: []const []const u8 = &.{
        "Time:      7  15   30",
        "Distance:  9  40  200",
    };
    const numbers: []const usize = &.{
        71530,
        940200,
    };
    for (lines, numbers) |line, expected| {
        const got = try getNumberFromLine(line, std.testing.allocator);
        try std.testing.expectEqual(expected, got);
    }
}
