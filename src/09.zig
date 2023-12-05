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
    try nextChunk(reader, &buffer);
    var seeds_buf: [32]usize = undefined;
    const seeds = try getSeeds(buffer.items, &seeds_buf);
    buffer.clearRetainingCapacity();

    var done = false;
    while (!done) {
        nextChunk(reader, &buffer) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        try mapThroughTransform(buffer.items, seeds);
        buffer.clearRetainingCapacity();
    }

    const min = std.mem.min(usize, seeds);
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{min});
    try bw.flush();
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

fn getSeeds(seeds_str: []const u8, buffer: []usize) ![]usize {
    const seeds = "seeds: ";
    const substr = seeds_str[seeds.len..];
    var iterator = std.mem.tokenizeAny(u8, substr, " \n");
    var idx: usize = 0;
    while (iterator.next()) |seed| : (idx += 1) {
        buffer[idx] = try std.fmt.parseUnsigned(usize, seed, 10);
    }
    return buffer[0..idx];
}

fn mapThroughTransform(spec_str: []const u8, input_buffer: []usize) !void {
    var ranges_buf: [64][3]usize = undefined;
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
    for (input_buffer) |*input| {
        for (ranges) |range| {
            if (input.* >= range[1] and input.* < range[1] + range[2]) {
                const transform: i128 = @as(i128, range[0]) - range[1];
                input.* = @intCast(input.* + transform);
                break;
            }
        }
    }
}

test "mapThroughTransform" {
    var seeds: [4]usize = .{ 79, 14, 55, 13 };
    const expected: []const []const usize = &.{
        &.{ 81, 14, 57, 13 },
        &.{ 81, 53, 57, 52 },
        &.{ 81, 49, 53, 41 },
        &.{ 74, 42, 46, 34 },
        &.{ 78, 42, 82, 34 },
        &.{ 78, 43, 82, 35 },
        &.{ 82, 43, 86, 35 },
    };
    for (test_chunks[1..], expected) |chunk, expectation| {
        try mapThroughTransform(chunk, &seeds);
        for (seeds, expectation) |got, value| {
            try std.testing.expectEqual(value, got);
        }
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
