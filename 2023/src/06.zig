const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();
    const filename = try parseArgs(allocator);
    const reader = try getReaderFromFilename(filename);
    allocator.free(filename);
    var buffer = std.ArrayList(u8).init(allocator);
    var prev: ?[]const u8 = null;
    var curr: ?[]const u8 = curr: {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break :curr null else return err;
        };
        break :curr try buffer.toOwnedSlice();
    };
    var next: ?[]const u8 = next: {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break :next null else return err;
        };
        break :next try buffer.toOwnedSlice();
    };
    var count: usize = 0;
    while (curr) |line| {
        count += try processLines(prev, line, next);
        if (prev) |p| allocator.free(p);
        prev = curr;
        curr = next;
        next = next: {
            reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
                if (err == error.EndOfStream) break :next null else return err;
            };
            break :next try buffer.toOwnedSlice();
        };
    }
    if (prev) |p| allocator.free(p);
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
        std.debug.print("pass the filename as the first argument!\n", .{});
        std.process.exit(1);
    };
    while (args.next()) |arg| {
        std.debug.print("ignoring arg: {s}\n", .{arg});
        allocator.free(arg);
    }
    return filename;
}

fn getReaderFromFilename(filename: [:0]const u8) !std.fs.File.Reader {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    return file.reader();
}

fn processLines(prev: ?[]const u8, curr: []const u8, next: ?[]const u8) !usize {
    var count: usize = 0;
    var gear = std.mem.indexOfScalar(u8, curr, '*');
    while (gear) |idx| {
        const numbers_found: usize, const multiply: usize = find: {
            var number: usize = 0;
            var multiply: usize = 1;
            const start = idx -| 1;
            const end: usize = @min(idx + 1, curr.len);
            const others: []const ?[]const u8 = &.{ prev, next };
            for (others) |other| {
                if (other) |line| {
                    if (isDigit(line[idx])) {
                        const num_start = findDigitsStart(line[0..end]);
                        const num_end = if (end < line.len) end + findDigitsEnd(line[end..]) else line.len;
                        number += 1;
                        multiply *= try std.fmt.parseUnsigned(usize, line[num_start..num_end], 10);
                    } else {
                        if (isDigit(line[start])) {
                            const num_start = findDigitsStart(line[0..idx]);
                            number += 1;
                            multiply *= try std.fmt.parseUnsigned(usize, line[num_start..idx], 10);
                        }
                        if (end < line.len and isDigit(line[end])) {
                            const num_end = end + findDigitsEnd(line[end..]);
                            number += 1;
                            multiply *= try std.fmt.parseUnsigned(usize, line[end..num_end], 10);
                        }
                    }
                }
            }
            if (isDigit(curr[start])) {
                const num_start = findDigitsStart(curr[0..idx]);
                number += 1;
                multiply *= try std.fmt.parseUnsigned(usize, curr[num_start..idx], 10);
            }
            if (end < curr.len and isDigit(curr[end])) {
                const num_end = end + findDigitsEnd(curr[end..]);
                number += 1;
                multiply *= try std.fmt.parseUnsigned(usize, curr[end..num_end], 10);
            }
            break :find .{ number, multiply };
        };
        count += if (numbers_found != 2) 0 else multiply;
        gear = std.mem.indexOfScalarPos(u8, curr, @min(idx + 1, curr.len), '*');
    }
    return count;
}

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn findDigitsStart(slice: []const u8) usize {
    const digits = "0123456789";
    return if (std.mem.lastIndexOfNone(u8, slice, digits)) |num| num + 1 else 0;
}

fn findDigitsEnd(slice: []const u8) usize {
    const digits = "0123456789";
    return std.mem.indexOfNone(u8, slice, digits) orelse slice.len;
}

test "indexOf" {
    const input = ".....123....";
    const start = std.mem.indexOfAny(u8, input, "0123456789") orelse return error.Fail;
    const end = std.mem.indexOfNonePos(u8, input, start, "0123456789") orelse return error.Fail;
    try std.testing.expectEqualStrings("123", input[start..end]);
}

test "processlines" {
    const lines: []const []const u8 = &.{
        "467..114..",
        "...*......",
        "..35..633.",
        "......#...",
        "617*......",
        ".....+.58.",
        "..592.....",
        "......755.",
        "...$.*....",
        ".664.598..",
    };
    const expected: []const usize = &.{ 0, 16345, 0, 0, 0, 0, 0, 0, 451490, 0 };
    for (lines, 0.., expected) |line, i, val| {
        const prev: ?[]const u8 = if (i > 0) lines[i - 1] else null;
        const next: ?[]const u8 = if (i < lines.len - 1) lines[i + 1] else null;
        try std.testing.expectEqual(val, try processLines(prev, line, next));
    }
}
