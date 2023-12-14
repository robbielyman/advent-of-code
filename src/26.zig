const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const reader = reader: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :reader try getReaderFromFilename(filename);
    };
    defer reader.context.close();
    var done = false;
    var count: usize = 0;
    while (!done) {
        const rect = try getRect(allocator, reader);
        defer {
            for (rect) |r| allocator.free(r);
            allocator.free(rect);
        }
        if (rect.len == 0) {
            done = true;
            break;
        }
        const tcer = try transpose(allocator, rect);
        defer {
            for (tcer) |t| allocator.free(t);
            allocator.free(tcer);
        }
        var found = false;
        if (findReflection(rect)) |row| {
            count += 100 * row;
            std.debug.print("\nROW REFLECTION: row {d}\n", .{row});
            for (rect) |line| {
                std.debug.print("{s}\n", .{line});
            }
            found = true;
        }
        if (findReflection(tcer)) |col| {
            count += col;
            std.debug.print("\nCOLUMN REFLECTION: col {d}\n", .{col});
            for (rect) |line| {
                std.debug.print("{s}\n", .{line});
            }
            found = true;
        }
        if (!found) {
            std.debug.print("\nNO REFLECTION!?\n", .{});
            for (rect) |line| {
                std.debug.print("{s}\n", .{line});
            }
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn getRect(allocator: std.mem.Allocator, reader: std.fs.File.Reader) ![]const []const u8 {
    var buffer = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (buffer.items) |i| allocator.free(i);
        buffer.deinit();
    }
    var scratch = std.ArrayList(u8).init(allocator);
    defer scratch.deinit();
    var done = false;
    while (!done) {
        reader.streamUntilDelimiter(scratch.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        defer scratch.clearRetainingCapacity();
        if (scratch.items.len == 0) break;
        try buffer.append(try allocator.dupe(u8, scratch.items));
    }
    return try buffer.toOwnedSlice();
}

fn getReaderFromFilename(filename: []const u8) !std.fs.File.Reader {
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

fn transpose(allocator: std.mem.Allocator, input: []const []const u8) ![]const []const u8 {
    for (input) |line| {
        if (line.len != input[0].len) return error.InputNotRectangular;
    }
    const output = try allocator.alloc([]u8, input[0].len);
    for (output, 0..) |*column, i| {
        const new_col = try allocator.alloc(u8, input.len);
        for (input, new_col) |line, *val| {
            val.* = line[i];
        }
        column.* = new_col;
    }
    return output;
}

test "transpose" {
    const input: []const []const u8 = &.{ "11", "01" };
    const output: []const []const u8 = &.{ "10", "11" };
    const got = try transpose(std.testing.allocator, input);
    defer std.testing.allocator.free(got);
    for (output, got) |val, g| {
        defer std.testing.allocator.free(g);
        try std.testing.expectEqualStrings(val, g);
    }
}

fn oneDifference(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    var found = false;
    for (a, b) |x, y| {
        if (x == y) continue;
        if (!found) {
            found = true;
            continue;
        }
        return false;
    }
    return found;
}

fn findReflection(input: []const []const u8) ?usize {
    for (0..input.len - 1) |n| {
        var i: usize = 0;
        var found = false;
        while (i <= n and n + 1 + i < input.len) : (i += 1) {
            if (std.mem.eql(u8, input[n - i], input[n + 1 + i])) {
                continue;
            } else {
                if (!found and oneDifference(u8, input[n - i], input[n + 1 + i])) {
                    found = true;
                    continue;
                }
            }
            break;
        } else if (found) return n + 1;
    }
    return null;
}

test "findReflection" {
    const input: []const []const []const u8 = &.{ &.{
        "#.##..##.",
        "..#.##.#.",
        "##......#",
        "##......#",
        "..#.##.#.",
        "..##..##.",
        "#.#.##.#.",
    }, &.{
        "#...##..#",
        "#....#..#",
        "..##..###",
        "#####.##.",
        "#####.##.",
        "..##..###",
        "#....#..#",
    } };
    const expected: []const []const ?usize = &.{
        &.{ null, 5 }, &.{ 4, null },
    };
    const allocator = std.testing.allocator;
    var count: usize = 0;
    for (input, expected) |rect, e| {
        const rectT = try transpose(allocator, rect);
        defer {
            for (rectT) |r| allocator.free(r);
            allocator.free(rectT);
        }
        try std.testing.expectEqual(e[0], findReflection(rect));
        try std.testing.expectEqual(e[1], findReflection(rectT));
        if (findReflection(rect)) |row| count += 100 * row;
        if (findReflection(rectT)) |col| count += col;
    }
    try std.testing.expectEqual(@as(usize, 405), count);
}
