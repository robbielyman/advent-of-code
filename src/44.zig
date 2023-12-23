const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var blocks = std.ArrayList(Block).init(allocator);
    defer blocks.deinit();
    {
        const reader = reader: {
            const filename = try parseArgs(allocator);
            defer allocator.free(filename);
            break :reader try getReaderFromFilename(filename);
        };
        defer reader.context.close();

        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        var done = false;
        while (!done) {
            defer buffer.clearRetainingCapacity();
            reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
                if (err == error.EndOfStream) done = true else return err;
            };
            if (buffer.items.len > 0) {
                const block = try parseInput(buffer.items);
                try blocks.append(block);
            }
        }
    }
    std.mem.sort(Block, blocks.items, {}, Block.lessThan);
    while (drop(blocks.items)) {}
    var count: usize = 0;
    for (0..blocks.items.len) |i| {
        const slice = try allocator.dupe(Block, blocks.items);
        var list = std.ArrayList(Block).fromOwnedSlice(allocator, slice);
        defer list.deinit();
        _ = list.orderedRemove(i);
        while (drop(list.items)) count += 1;
        std.debug.print("count after dropping block {d}: {d}\n", .{ i + 1, count });
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
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
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

fn parseInput(line: []const u8) !Block {
    const idx = std.mem.indexOfScalar(u8, line, '~') orelse return error.ParseFailed;
    const origin: Block.Point = origin: {
        var tokenizer = std.mem.tokenizeScalar(u8, line[0..idx], ',');
        var coord: [3]usize = undefined;
        var id: usize = 0;
        while (tokenizer.next()) |token| : (id += 1) {
            if (id >= 3) return error.ParseFailed;
            coord[id] = try std.fmt.parseUnsigned(usize, token, 10);
        }
        if (id != 3) return error.ParseFailed;
        break :origin .{ .x = coord[0], .y = coord[1], .z = coord[2] };
    };
    const corner: Block.Point = corner: {
        var tokenizer = std.mem.tokenizeScalar(u8, line[idx + 1 ..], ',');
        var coord: [3]usize = undefined;
        var id: usize = 0;
        while (tokenizer.next()) |token| : (id += 1) {
            if (id >= 3) return error.ParseFailed;
            coord[id] = try std.fmt.parseUnsigned(usize, token, 10);
        }
        if (id != 3) return error.ParseFailed;
        break :corner .{ .x = coord[0], .y = coord[1], .z = coord[2] };
    };
    return .{
        .origin = origin,
        .corner = corner,
    };
}

const Node = struct {
    children: []const usize,
    parents: []const usize,
};

test "parseInput" {
    std.testing.log_level = .info;
    const input =
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
    ;
    const blocks: []const Block = &.{
        .{
            .origin = .{ .x = 1, .y = 0, .z = 1 },
            .corner = .{ .x = 1, .y = 2, .z = 1 },
        },
        .{
            .origin = .{ .x = 0, .y = 0, .z = 2 },
            .corner = .{ .x = 2, .y = 0, .z = 2 },
        },
        .{
            .origin = .{ .x = 0, .y = 2, .z = 3 },
            .corner = .{ .x = 2, .y = 2, .z = 3 },
        },
        .{
            .origin = .{ .x = 0, .y = 0, .z = 4 },
            .corner = .{ .x = 0, .y = 2, .z = 4 },
        },
        .{
            .origin = .{ .x = 2, .y = 0, .z = 5 },
            .corner = .{ .x = 2, .y = 2, .z = 5 },
        },
        .{
            .origin = .{ .x = 0, .y = 1, .z = 6 },
            .corner = .{ .x = 2, .y = 1, .z = 6 },
        },
        .{
            .origin = .{ .x = 1, .y = 1, .z = 8 },
            .corner = .{ .x = 1, .y = 1, .z = 9 },
        },
    };
    const allocator = std.testing.allocator;
    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    var list = std.ArrayList(Block).init(allocator);
    defer list.deinit();
    while (tokenizer.next()) |line| {
        const block = try parseInput(line);
        try list.append(block);
    }
    for (list.items[0..list.items.len], blocks) |got, expected| {
        try std.testing.expectEqualDeep(expected, got);
    }
}

const Block = struct {
    origin: Point,
    corner: Point,

    const Point = struct {
        x: usize,
        y: usize,
        z: usize,
    };

    fn compareFn(context: void, a: Block, b: Block) std.math.Order {
        _ = context;
        if (a.origin.z < b.origin.z) return .lt;
        if (a.origin.z > b.origin.z) return .gt;
        if (a.origin.y < b.origin.y) return .lt;
        if (a.origin.y > b.origin.y) return .gt;
        if (a.origin.x < b.origin.x) return .lt;
        if (a.origin.x > b.origin.y) return .gt;
        return .eq;
    }

    fn lessThan(context: void, a: Block, b: Block) bool {
        return Block.compareFn(context, a, b) == .lt;
    }

    fn overlap(a: Block, b: Block) bool {
        const x_overlap = (a.origin.x <= b.origin.x and b.origin.x <= a.corner.x) or
            (b.origin.x <= a.origin.x and a.origin.x <= b.corner.x);
        const y_overlap = (a.origin.y <= b.origin.y and b.origin.y <= a.corner.y) or
            (b.origin.y <= a.origin.y and a.origin.y <= b.corner.y);
        const z_overlap = (a.origin.z <= b.origin.z and b.origin.z <= a.corner.z) or
            (b.origin.z <= a.origin.z and a.origin.z <= b.corner.z);
        return x_overlap and y_overlap and z_overlap;
    }

    fn eql(a: Block, b: Block) bool {
        return a.origin.x == b.origin.x and a.origin.y == b.origin.y and a.origin.z == b.origin.z and
            a.corner.x == b.corner.x and a.origin.y == b.origin.y and a.origin.z == b.origin.z;
    }
};

fn canDrop(sorted_blocks: []const Block, idx: usize) bool {
    const block = sorted_blocks[idx];
    if (block.origin.z == 1) return false;
    const new: Block = .{
        .corner = .{
            .x = block.corner.x,
            .y = block.corner.y,
            .z = block.corner.z - 1,
        },
        .origin = .{
            .x = block.origin.x,
            .y = block.origin.y,
            .z = block.origin.z - 1,
        },
    };
    for (sorted_blocks[0..idx]) |other| {
        if (new.overlap(other)) return false;
    }
    return true;
}

fn drop(sorted_blocks: []Block) bool {
    var restart = false;
    for (sorted_blocks, 0..) |*block, i| {
        restart = canDrop(sorted_blocks, i);
        while (canDrop(sorted_blocks, i)) {
            block.corner.z -= 1;
            block.origin.z -= 1;
        }
        if (restart) break;
    }
    if (restart) {
        std.mem.sort(Block, sorted_blocks, {}, Block.lessThan);
    }
    return restart;
}

test "dropBlocks" {
    const input: []const Block = &.{
        .{
            .origin = .{ .x = 1, .y = 0, .z = 1 },
            .corner = .{ .x = 1, .y = 2, .z = 1 },
        },
        .{
            .origin = .{ .x = 0, .y = 0, .z = 2 },
            .corner = .{ .x = 2, .y = 0, .z = 2 },
        },
        .{
            .origin = .{ .x = 0, .y = 2, .z = 3 },
            .corner = .{ .x = 2, .y = 2, .z = 3 },
        },
        .{
            .origin = .{ .x = 0, .y = 0, .z = 4 },
            .corner = .{ .x = 0, .y = 2, .z = 4 },
        },
        .{
            .origin = .{ .x = 2, .y = 0, .z = 5 },
            .corner = .{ .x = 2, .y = 2, .z = 5 },
        },
        .{
            .origin = .{ .x = 0, .y = 1, .z = 6 },
            .corner = .{ .x = 2, .y = 1, .z = 6 },
        },
        .{
            .origin = .{ .x = 1, .y = 1, .z = 8 },
            .corner = .{ .x = 1, .y = 1, .z = 9 },
        },
    };
    const allocator = std.testing.allocator;
    const blocks = try allocator.dupe(Block, input);
    defer allocator.free(blocks);
    std.mem.sort(Block, blocks, {}, Block.lessThan);
    while (drop(blocks)) {}
    var count: usize = 0;
    for (0..blocks.len) |i| {
        const slice = try allocator.dupe(Block, blocks);
        var list = std.ArrayList(Block).fromOwnedSlice(allocator, slice);
        defer list.deinit();
        _ = list.orderedRemove(i);
        while (drop(list.items)) count += 1;
    }
    try std.testing.expectEqual(@as(usize, 7), count);
}
