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
    var buffer = std.ArrayList(u8).init(allocator);
    var keys = Keys.init(allocator);
    defer {
        for (keys.items) |k| {
            allocator.free(k.chunk);
            allocator.free(k.numbers);
        }
        keys.deinit();
    }
    var map = Map.init(allocator);
    defer map.deinit();
    defer buffer.deinit();
    var done = false;
    var count: usize = 0;
    while (!done) {
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        defer buffer.clearRetainingCapacity();
        count += count: {
            const chunks, const numbers = parseInput(allocator, buffer.items) catch |err| {
                if (err == error.ParseFailed) break :count 0 else return err;
            };
            defer {
                for (chunks) |c| allocator.free(c);
                allocator.free(chunks);
                allocator.free(numbers);
            }
            break :count try countSolutions(allocator, numbers, chunks, &keys, &map);
        };
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
    const filename = args.next() orelse return error.NoFilename;
    return try allocator.dupe(u8, filename);
}

const Key = struct {
    numbers: []const usize,
    chunk: []const u8,
};
const Keys = std.ArrayList(Key);

const Context = struct {
    pub fn hash(ctx: @This(), key: Key) u64 {
        _ = ctx;
        var h = std.hash.CityHash64.hash(key.chunk);
        var flip = false;
        for (key.numbers) |number| {
            if (flip) h += number else h -= number;
            flip = !flip;
        }
        return h;
    }
    pub fn eql(ctx: @This(), a: Key, b: Key) bool {
        _ = ctx;
        return std.mem.eql(u8, a.chunk, b.chunk) and std.mem.eql(usize, a.numbers, b.numbers);
    }
};

const Map = std.HashMap(Key, usize, Context, 80);

fn countInChunk(
    allocator: std.mem.Allocator,
    numbers: []const usize,
    chunk: []const u8,
    keys: *Keys,
    map: *Map,
) !usize {
    if (chunk.len == 0) {
        if (numbers.len == 0) return 1 else return 0;
    }
    if (numbers.len == 0) {
        return if (std.mem.indexOfScalar(u8, chunk, '#') == null) 1 else 0;
    }
    if (map.get(.{
        .numbers = numbers,
        .chunk = chunk,
    })) |val| return val;
    const val = val: {
        switch (chunk[0]) {
            '#' => if (numbers.len > 1) {
                break :val if (canMatchWithSeparator(chunk, numbers[0]))
                    try countInChunk(allocator, numbers[1..], chunk[numbers[0] + 1 ..], keys, map)
                else
                    0;
            } else {
                break :val if (chunk.len >= numbers[0])
                    try countInChunk(allocator, numbers[1..], chunk[numbers[0]..], keys, map)
                else
                    0;
            },
            '?' => {
                const c = try countInChunk(allocator, numbers, chunk[1..], keys, map);
                const d = d: {
                    if (numbers.len > 1) {
                        break :d if (canMatchWithSeparator(chunk, numbers[0]))
                            try countInChunk(allocator, numbers[1..], chunk[numbers[0] + 1 ..], keys, map)
                        else
                            0;
                    } else {
                        break :d if (chunk.len >= numbers[0])
                            try countInChunk(allocator, numbers[1..], chunk[numbers[0]..], keys, map)
                        else
                            0;
                    }
                };
                break :val c + d;
            },
            else => unreachable,
        }
    };
    const key: Key = .{
        .chunk = try allocator.dupe(u8, chunk),
        .numbers = try allocator.dupe(usize, numbers),
    };
    try keys.append(key);
    try map.put(key, val);
    return val;
}

fn canMatchWithSeparator(chunk: []const u8, number: usize) bool {
    if (chunk.len < number + 1) return false;
    if (chunk[number] != '?') return false;
    return true;
}

fn pullFromStart(chunk: []const u8, numbers: []const usize) usize {
    var idx: usize = 0;
    var length: usize = 0;
    while (length < chunk.len and idx < numbers.len) {
        length += numbers[idx];
        if (idx > 0) length += 1;
        idx += 1;
    }
    return idx;
}

fn countSolutions(
    allocator: std.mem.Allocator,
    numbers: []const usize,
    chunks: []const []const u8,
    keys: *Keys,
    map: *Map,
) !usize {
    if (numbers.len == 0 and chunks.len == 0) return 1;
    if (chunks.len == 0) return 0;

    const chunks_key = key: {
        var list = std.ArrayList(u8).init(allocator);
        defer list.deinit();
        for (chunks) |chunk| {
            try list.appendSlice(chunk);
            try list.append('.');
        }
        break :key try list.toOwnedSlice();
    };
    defer allocator.free(chunks_key);

    if (map.get(.{
        .chunk = chunks_key,
        .numbers = numbers,
    })) |val| return val;

    var count: usize = 0;
    const pull = pullFromStart(chunks[0], numbers);
    if (chunks.len == 1) {
        const c = try countInChunk(allocator, numbers, chunks[0], keys, map);
        return c;
    }
    for (0..pull + 1) |n| {
        const c = try countInChunk(allocator, numbers[0..n], chunks[0], keys, map);
        if (c == 0) continue;
        count += c * try countSolutions(allocator, numbers[n..], chunks[1..], keys, map);
    }

    const key: Key = .{
        .chunk = try allocator.dupe(u8, chunks_key),
        .numbers = try allocator.dupe(usize, numbers),
    };
    try keys.append(key);
    try map.put(key, count);
    
    return count;
}

fn parseInput(allocator: std.mem.Allocator, line: []const u8) !struct {
    []const []const u8,
    []const usize,
} {
    const row_end = std.mem.indexOfScalar(u8, line, ' ') orelse return error.ParseFailed;
    const chunks: []const []const u8 = chunks: {
        const r = line[0..row_end];
        const row = try std.fmt.allocPrint(allocator, "{s}?{s}?{s}?{s}?{s}", .{ r, r, r, r, r });
        defer allocator.free(row);
        var chunks = std.ArrayList([]const u8).init(allocator);
        errdefer {
            for (chunks.items) |i| allocator.free(i);
            chunks.deinit();
        }
        var tokenizer = std.mem.tokenizeScalar(u8, row, '.');
        while (tokenizer.next()) |token| {
            try chunks.append(try allocator.dupe(u8, token));
        }
        break :chunks try chunks.toOwnedSlice();
    };
    const counts: []const usize = counts: {
        const r = line[row_end + 1 ..];
        const rest = try std.fmt.allocPrint(allocator, "{s},{s},{s},{s},{s}", .{ r, r, r, r, r });
        defer allocator.free(rest);
        var counts = std.ArrayList(usize).init(allocator);
        errdefer counts.deinit();
        var tokenizer = std.mem.tokenizeScalar(u8, rest, ',');
        while (tokenizer.next()) |token| {
            const number = try std.fmt.parseUnsigned(usize, token, 10);
            try counts.append(number);
        }
        break :counts try counts.toOwnedSlice();
    };
    return .{ chunks, counts };
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
    const outcomes: []const usize = &.{ 1, 16384, 1, 16, 2500, 506250 };
    const allocator = std.testing.allocator;
    var keys = Keys.init(allocator);
    defer {
        for (keys.items) |key| {
            allocator.free(key.chunk);
            allocator.free(key.numbers);
        }
        keys.deinit();
    }
    var map = Map.init(allocator);
    defer map.deinit();
    for (input, outcomes, 1..) |line, expected, i| {
        _ = i;

        const chunks, const numbers = try parseInput(allocator, line);
        defer {
            for (chunks) |chunk| allocator.free(chunk);
            allocator.free(chunks);
            allocator.free(numbers);
        }
        const got = try countSolutions(allocator, numbers, chunks, &keys, &map);
        try std.testing.expectEqual(expected, got);
    }
}
