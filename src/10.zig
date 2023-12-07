const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const filename = try processArgs(allocator);
    var reader = try getReaderFromFilename(filename);
    allocator.free(filename);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try nextChunk(reader, &buffer);
    var seeds_buf: [32]Range = undefined;
    const seeds = try getSeeds(buffer.items, &seeds_buf);
    buffer.clearRetainingCapacity();

    var input_ranges = std.ArrayList(Range).init(allocator);
    defer input_ranges.deinit();
    var output_ranges = std.ArrayList(Range).init(allocator);
    defer output_ranges.deinit();

    var done = false;
    try input_ranges.appendSlice(seeds);
    var ranges_buf: [64][3]usize = undefined;
    while (!done) {
        nextChunk(reader, &buffer) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        const ranges = try getRanges(buffer.items, &ranges_buf);
        try remapRanges(ranges, &input_ranges, &output_ranges);
        input_ranges.clearRetainingCapacity();
        try input_ranges.appendSlice(output_ranges.items);
        output_ranges.clearRetainingCapacity();
        buffer.clearRetainingCapacity();
    }

    var min: usize = std.math.maxInt(usize);
    for (input_ranges.items) |range| {
        min = @min(min, range.start);
    }
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{min});
    try bw.flush();
    std.debug.print("{d} milliseconds\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
}

fn processArgs(allocator: std.mem.Allocator) ![]const u8 {
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

fn nextChunk(reader: anytype, buffer: *std.ArrayList(u8)) !void {
    var len = buffer.items.len;
    var done = false;
    while (!done) : (len = buffer.items.len) {
        try reader.streamUntilDelimiter(buffer.writer(), '\n', null);
        if (len == buffer.items.len) {
            done = true;
        } else {
            try buffer.append('\n');
        }
    }
}

fn getSeeds(seeds_str: []const u8, buffer: []Range) ![]const Range {
    const seeds = "seeds: ";
    const substr = seeds_str[seeds.len..];
    var iterator = std.mem.tokenizeAny(u8, substr, " \n");
    var idx: usize = 0;
    while (iterator.next()) |seed| : (idx += 1) {
        const start = try std.fmt.parseUnsigned(usize, seed, 10);
        const length_str = iterator.next() orelse return error.ParseFailed;
        const len = try std.fmt.parseUnsigned(usize, length_str, 10);
        buffer[idx] = .{
            .start = start,
            .len = len,
        };
    }
    return buffer[0..idx];
}

fn getRanges(spec_str: []const u8, ranges_buf: [][3]usize) ![]const [3]usize {
    var iterator = std.mem.tokenizeScalar(u8, spec_str, '\n');
    _ = iterator.next();
    var idx: usize = 0;
    const ranges = ranges: {
        while (iterator.next()) |line| : (idx += 1) {
            if (line.len == 0) break;
            var nums = std.mem.tokenizeScalar(u8, line, ' ');
            for (&ranges_buf[idx]) |*value| {
                const str = nums.next() orelse return error.ParseFailed;
                value.* = try std.fmt.parseUnsigned(usize, str, 10);
            }
        }
        break :ranges ranges_buf[0..idx];
    };
    return ranges;
}

fn remapRanges(
    filter: []const [3]usize,
    input_buf: *std.ArrayList(Range),
    output_buf: *std.ArrayList(Range),
) !void {
    while (input_buf.items.len != 0) {
        const input_range = input_buf.pop();
        for (filter) |value| {
            const filter_range: Range = .{
                .start = value[1],
                .len = value[2],
            };
            const sliced = input_range.slice(filter_range);
            if (sliced[1]) |intersection| {
                const transform: i128 = @as(i128, value[0]) - value[1];
                try output_buf.append(.{
                    .start = @intCast(intersection.start + transform),
                    .len = intersection.len,
                });
                if (sliced[0]) |s| try input_buf.append(s);
                if (sliced[2]) |s| try input_buf.append(s);
                break;
            }
        } else {
            try output_buf.append(input_range);
        }
    }
}

const Range = struct {
    start: usize,
    len: usize,

    fn slice(self: Range, other: Range) [3]?Range {
        const self_end = self.start + self.len;
        const other_end = other.start + other.len;
        const intersection_start = @max(self.start, other.start);
        const intersection_end = @min(self_end, other_end);
        const left: ?Range = if (self.start < other.start)
            .{ .start = self.start, .len = other.start - self.start }
        else
            null;
        const mid: ?Range = if (intersection_end > intersection_start)
            .{ .start = intersection_start, .len = intersection_end - intersection_start }
        else
            null;
        const right: ?Range = if (self_end > other_end)
            .{ .start = other_end, .len = self_end - other_end }
        else
            null;
        return .{ left, mid, right };
    }
};

test "getRanges" {
    var buf: [16][3]usize = undefined;
    for (test_chunks[1..], test_ranges) |chunk, ranges| {
        const got = try getRanges(chunk, &buf);
        try std.testing.expectEqualSlices([3]usize, ranges, got);
    }
}

test "intersect and difference" {
    const self: Range = .{
        .start = 0,
        .len = 100,
    };
    const others: []const Range = &.{
        .{ .start = 100, .len = 1 },
        .{ .start = 50, .len = 4 },
        .{ .start = 0, .len = 100 },
        .{ .start = 75, .len = 50 },
    };
    const expected: []const [3]?Range = &.{
        .{ .{ .start = 0, .len = 100 }, null, null },
        .{ .{ .start = 0, .len = 50 }, .{ .start = 50, .len = 4 }, .{ .start = 54, .len = 46 } },
        .{ null, .{ .start = 0, .len = 100 }, null },
        .{ .{ .start = 0, .len = 75 }, .{ .start = 75, .len = 25 }, null },
    };
    for (others, expected) |other, slice| {
        try std.testing.expectEqualSlices(?Range, &slice, &self.slice(other));
    }
}

test "getSeeds" {
    var buffer: [16]usize = undefined;
    const seeds = try getSeeds(test_chunks[0], &buffer);
    const expected: []const usize = &.{ 79, 14, 55, 13 };
    for (seeds, expected) |got, value| {
        try std.testing.expectEqual(value, got);
    }
}

test "nextChunk" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const MockReader = struct {
        context: std.mem.SplitIterator(u8, .scalar),
        fn streamUntilDelimiter(self: *@This(), writer: anytype, delimiter: u8, max_size: ?usize) !void {
            _ = max_size;
            std.debug.assert(delimiter == '\n');
            if (self.context.next()) |bytes| {
                _ = try writer.write(bytes);
            }
            if (self.context.peek() == null) return error.EndOfStream;
        }
    };
    var mock_reader: MockReader = .{
        .context = std.mem.splitScalar(u8, test_input, '\n'),
    };
    for (test_chunks) |chunk| {
        nextChunk(&mock_reader, &buffer) catch |err| {
            if (err != error.EndOfStream) return err;
        };
        try std.testing.expectEqualStrings(chunk, buffer.items);
        buffer.clearRetainingCapacity();
    }
}

const test_input =
    \\seeds: 79 14 55 13
    \\
    \\seed-to-soil map:
    \\50 98 2
    \\52 50 48
    \\
    \\soil-to-fertilizer map:
    \\0 15 37
    \\37 52 2
    \\39 0 15
    \\
    \\fertilizer-to-water map:
    \\49 53 8
    \\0 11 42
    \\42 0 7
    \\57 7 4
    \\
    \\water-to-light map:
    \\88 18 7
    \\18 25 70
    \\
    \\light-to-temperature map:
    \\45 77 23
    \\81 45 19
    \\68 64 13
    \\
    \\temperature-to-humidity map:
    \\0 69 1
    \\1 0 69
    \\
    \\humidity-to-location map:
    \\60 56 37
    \\56 93 4
;

const test_chunks: []const []const u8 = &.{
    "seeds: 79 14 55 13\n",
    \\seed-to-soil map:
    \\50 98 2
    \\52 50 48
    \\
    ,
    \\soil-to-fertilizer map:
    \\0 15 37
    \\37 52 2
    \\39 0 15
    \\
    ,
    \\fertilizer-to-water map:
    \\49 53 8
    \\0 11 42
    \\42 0 7
    \\57 7 4
    \\
    ,
    \\water-to-light map:
    \\88 18 7
    \\18 25 70
    \\
    ,
    \\light-to-temperature map:
    \\45 77 23
    \\81 45 19
    \\68 64 13
    \\
    ,
    \\temperature-to-humidity map:
    \\0 69 1
    \\1 0 69
    \\
    ,
    \\humidity-to-location map:
    \\60 56 37
    \\56 93 4
    ,
};

const test_ranges: []const []const [3]usize = &.{
    &.{
        .{ 50, 98, 2 },
        .{ 52, 50, 48 },
    },
    &.{
        .{ 0, 15, 37 },
        .{ 37, 52, 2 },
        .{ 39, 0, 15 },
    },
    &.{
        .{ 49, 53, 8 },
        .{ 0, 11, 42 },
        .{ 42, 0, 7 },
        .{ 57, 7, 4 },
    },
    &.{
        .{ 88, 18, 7 },
        .{ 18, 25, 70 },
    },
    &.{
        .{ 45, 77, 23 },
        .{ 81, 45, 19 },
        .{ 68, 64, 13 },
    },
    &.{
        .{ 0, 69, 1 },
        .{ 1, 0, 69 },
    },
    &.{
        .{ 60, 56, 37 },
        .{ 56, 93, 4 },
    },
};
