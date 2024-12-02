const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var reader = reader: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :reader try getReaderFromFilename(filename);
    };
    defer reader.context.close();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    const done = false;
    var count: usize = 0;
    while (!done) {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        const line, const counts = try parseInput(allocator, buffer.items);
        defer allocator.free(line);
        
        const bars = try createBars(allocator, counts);
        allocator.free(counts);
        defer {
            for (bars) |bar| allocator.free(bar);
            allocator.free(bars);
        }

        count += countSolutions(bars, line);
        buffer.clearRetainingCapacity();
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
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
    const filename = args.next() orelse return error.NoFilenameFound;
    return try allocator.dupe(u8, filename);
}

fn startsWithWildcard(match_against: []const u8, with_wildcards: []const u8) bool {
    if (with_wildcards.len < match_against.len) return false;
    for (match_against, 0..) |char, i| {
        if (with_wildcards[i] == '?') continue;
        if (char != with_wildcards[i]) return false;
    }
    return true;
}

test "startsWithWildcard" {
    const match_against = "#.#";
    const with_wildcards: []const []const u8 = &.{
        "???", ".??", "#??", "?.?", "?#?",
    };
    const expected: []const bool = &.{
        true, false, true, true, false,
    };
    for (with_wildcards, expected) |token, value| {
        try std.testing.expectEqual(value, startsWithWildcard(match_against, token));
    }
}

fn indexOfBar(bar: []const u8, remainder: []const u8) ?usize {
    var idx: usize = 0;
    while (idx < remainder.len) : (idx += 1) {
        if (startsWithWildcard(bar, remainder[idx..])) return idx;
        if (remainder[idx] == '#') return null;
    } else return null;
}

test "indexOfBar" {
    const bar = "###.";
    const line = "###.????.#.?.??#.";
    try std.testing.expectEqual(@as(?usize, 0), indexOfBar(bar, line));
    try std.testing.expectEqual(@as(?usize, null), indexOfBar(bar, line[1..]));
    try std.testing.expectEqual(@as(?usize, 1), indexOfBar(bar, line[3..]));
}

fn countSolutions(bars: []const []const u8, line: []const u8) usize {
    const Iterator = struct {
        bar: []const u8,
        index: ?usize,
        line: []const u8,

        fn init(bar: []const u8, remainder: []const u8) @This() {
            return .{
                .bar = bar,
                .index = indexOfBar(bar, remainder),
                .line = remainder,
            };
        }
        fn next(self: *@This()) ?usize {
            const idx = self.index orelse return null;
            self.index = index: {
                if (self.line[idx] == '#') break :index null;
                const n = indexOfBar(self.bar, self.line[idx + 1 ..]) orelse break :index null;
                break :index n + idx + 1;
            };
            return idx;
        }
    };
    var iterator = Iterator.init(bars[0], line);
    var count: usize = 0;
    if (bars.len == 1) {
        while (iterator.next()) |idx| {
            if (std.mem.indexOfScalar(u8, line[idx + bars[0].len ..], '#') == null)
                count += 1;
        }
    } else {
        while (iterator.next()) |idx| {
            count += countSolutions(bars[1..], line[idx + bars[0].len ..]);
        }
    }
    return count;
}

fn createBars(allocator: std.mem.Allocator, counts: []const usize) ![]const []const u8 {
    const bars = try allocator.alloc([]u8, counts.len);
    var id: usize = 0;
    errdefer {
        for (bars[0..id]) |b| allocator.free(b);
        allocator.free(bars);
    }
    for (bars, counts) |*ptr, count| {
        id += 1;
        if (id == counts.len) {
            const bar = try allocator.alloc(u8, count);
            @memset(bar, '#');
            ptr.* = bar;
        } else {
            const bar = try allocator.alloc(u8, count + 1);
            @memset(bar, '#');
            bar[count] = '.';
            ptr.* = bar;
        }
    }
    return bars;
}

fn parseInput(allocator: std.mem.Allocator, line: []const u8) !struct {
    []const u8,
    []const usize,
} {
    const row_end = std.mem.indexOfScalar(u8, line, ' ') orelse return error.ParseFailed;
    const row = line[0..row_end];
    const counts: []const usize = counts: {
        const rest = line[row_end + 1 ..];
        var counts = std.ArrayList(usize).init(allocator);
        errdefer counts.deinit();
        var tokenizer = std.mem.tokenizeScalar(u8, rest, ',');
        while (tokenizer.next()) |token| {
            const number = try std.fmt.parseUnsigned(usize, token, 10);
            try counts.append(number);
        }
        break :counts try counts.toOwnedSlice();
    };
    return .{ try allocator.dupe(u8, row), counts };
}

test "countSolutions" {
    const input: []const []const u8 = &.{
        "???.### 1,1,3",
        ".??..??...?##. 1,1,3",
        "?#?#?#?#?#?#?#? 1,3,1,6",
        "????.#...#... 4,1,1",
        "????.######..#####. 1,6,5",
        "?###???????? 3,2,1",
    };
    const counts: []const []const usize = &.{
        &.{ 1, 1, 3 }, &.{ 1, 1, 3 }, &.{ 1, 3, 1, 6 },
        &.{ 4, 1, 1 }, &.{ 1, 6, 5 }, &.{ 3, 2, 1 },
    };
    const outcomes: []const usize = &.{
        1, 4, 1, 1, 4, 10,
    };
    const allocator = std.testing.allocator;
    for (input, counts, outcomes) |line, expected_count, outcome| {
        const row, const count = try parseInput(allocator, line);
        defer allocator.free(row);
        defer allocator.free(count);
        try std.testing.expectEqualSlices(usize, expected_count, count);
        const bars = try createBars(allocator, count);
        defer {
            for (bars) |bar| allocator.free(bar);
            allocator.free(bars);
        }
        const got = countSolutions(bars, row);
        try std.testing.expectEqual(outcome, got);
    }
}
