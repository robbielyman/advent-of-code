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
    const digits = "0123456789";
    var start = std.mem.indexOfAny(u8, curr, digits);
    while (start) |idx| {
        const end = std.mem.indexOfNonePos(u8, curr, idx, digits) orelse curr.len;
        const number = try std.fmt.parseUnsigned(usize, curr[idx..end], 10);
        count += blk: {
            const new_idx = idx -| 1;
            const new_end = @min(end + 1, curr.len);
            if (new_idx != idx and curr[new_idx] != '.') break :blk number;
            if (new_end != end and curr[new_end - 1] != '.') break :blk number;
            if (prev) |p| {
                if (std.mem.indexOfNone(u8, p[new_idx..new_end], digits ++ .{'.'})) |_| break :blk number;
            }
            if (next) |n| {
                if (std.mem.indexOfNone(u8, n[new_idx..new_end], digits ++ .{'.'})) |_| break :blk number;
            }
            break :blk 0;
        };
        start = std.mem.indexOfAnyPos(u8, curr, end, digits);
    }
    return count;
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
    const expected: []const usize = &.{ 467, 0, 668, 0, 617, 0, 592, 755, 0, 1262 };
    for (lines, 0.., expected) |line, i, val| {
        const prev: ?[]const u8 = if (i > 0) lines[i - 1] else null;
        const next: ?[]const u8 = if (i < lines.len - 1) lines[i + 1] else null;
        try std.testing.expectEqual(val, try processLines(prev, line, next));
    }
}
