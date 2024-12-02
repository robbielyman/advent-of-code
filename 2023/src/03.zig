const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
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
        defer buffer.clearRetainingCapacity();
        count += processLine(buffer.items) catch |err| blk: {
            if (err == error.ParseFailed) break :blk 0;
            return err;
        };
    }
    reader.context.close();
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

fn processLine(line: []const u8) !u64 {
    const line_number, const red, const green, const blue = blk: {
        const line_number, const remainder = remainder: {
            var iterator = std.mem.tokenizeSequence(u8, line, ": ");
            const start = iterator.next() orelse return error.ParseFailed;
            const remainder = iterator.rest();
            const game = "Game ";
            const idx = std.mem.lastIndexOf(u8, start, game) orelse return error.ParseFailed;
            const line_number = try std.fmt.parseUnsigned(u64, start[idx + game.len..], 10);
            break :remainder .{line_number, remainder};
        };
        var colors: [3]u64 = .{0 , 0 , 0};
        var iterator = std.mem.tokenizeSequence(u8, remainder, "; ");
        while (iterator.next()) |reveal| {
            var reveal_iterator = std.mem.tokenizeSequence(u8, reveal, ", ");
            while (reveal_iterator.next()) |token| {
                const colors_strings: []const []const u8 = &.{
                    " red",
                    " green",
                    " blue",
                };
                for (colors_strings, 0..) |color, i| {
                    const idx = std.mem.lastIndexOf(u8, token, color) orelse continue;
                    colors[i] = @max(try std.fmt.parseUnsigned(u64, token[0..idx], 10), colors[i]);
                }
            }
        }
        break :blk .{line_number, colors[0], colors[1], colors[2]};
    };
    return if (red <= 12 and green <= 13 and blue <= 14) line_number else 0;
}

test "processLine" {
    const games: []const []const u8 = &.{
        "Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green",
        "Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue",
        "Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red",
        "Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red",
        "Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green",
    };
    const expectations: [] const u64 = &.{ 1, 2, 0, 0, 5 };
    for (games, expectations) |game, result| {
        try std.testing.expectEqual(try processLine(game), result);
    }
}
