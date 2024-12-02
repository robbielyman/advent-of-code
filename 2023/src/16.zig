const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const filename = try parseArgs(allocator);
    const contents = try getFileContents(filename, allocator);
    defer allocator.free(contents);
    allocator.free(filename);

    const directions, const input = blk: {
        var splitter = std.mem.tokenizeScalar(u8, contents, '\n');
        const directions = splitter.next() orelse return error.ParseFailed;
        const input = splitter.rest();
        break :blk .{ directions, input };
    };

    var list = List.init(allocator);
    defer list.deinit();
    var map = Map.init(allocator);
    defer map.deinit();
    try buildGraph(input, &map, &list);
    const nodes = try findStartingNodes(list.items, map, allocator);
    defer allocator.free(nodes);
    var count: usize = 1;
    for (nodes) |node| {
        const next = try walk(node, directions);
        count = lcm(count, next);
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn walk(start: *Node, directions: []const u8) !usize {
    var done = false;
    var count: usize = 0;
    var node = start;
    while (!done) {
        for (directions) |direction| {
            count += 1;
            switch (direction) {
                'L' => node = node.left,
                'R' => node = node.right,
                else => return error.UnexpectedDirection,
            }
            if (node.id[node.id.len - 1] == 'Z') done = true;
            if (done) break;
        }
    }
    return count;
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

fn getFileContents(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    return try file.reader().readAllAlloc(allocator, 32 * 1024);
}

const Node = struct {
    id: []const u8,
    left: *Node,
    right: *Node,
};

const Map = std.StringHashMap(Node);
const List = std.ArrayList([]const u8);

fn findStartingNodes(keys: []const []const u8, map: Map, allocator: std.mem.Allocator) ![]*Node {
    var nodes = std.ArrayList(*Node).init(allocator);
    defer nodes.deinit();
    for (keys) |key| {
        if (key[key.len - 1] == 'A') {
            try nodes.append(map.getPtr(key) orelse return error.NodeNotFound);
        }
    }
    return try nodes.toOwnedSlice();
}

fn buildGraph(input: []const u8, map: *Map, keys: *List) !void {
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        const key = try keys.addOne();
        key.* = line[0..3];
        try map.put(key.*, .{
            .id = key.*,
            .left = undefined,
            .right = undefined,
        });
    }
    iterator.reset();
    while (iterator.next()) |line| {
        const key, const left, const right = split: {
            var splitter = std.mem.tokenizeAny(u8, line, " =(,)");
            const key = splitter.next() orelse return error.ParseFailed;
            const left = splitter.next() orelse return error.ParseFailed;
            const right = splitter.next() orelse return error.ParseFailed;
            break :split .{ key, left, right };
        };
        const node = map.getPtr(key) orelse return error.BuildFailed;
        const left_node = map.getPtr(left) orelse return error.BuildFailed;
        const right_node = map.getPtr(right) orelse return error.BuildFailed;
        node.left = left_node;
        node.right = right_node;
    }
}

fn lcm(a: usize, b: usize) usize {
    for (0..b) |i| {
        const multiple = a * (i + 1);
        if (multiple % b == 0) return multiple;
    }
    return a * b;
}

test "lcm" {
    const nums: []const usize = &.{ 4, 3, 6, 15 };
    const expected: []const usize = &.{ 4, 12, 12, 60 };
    var count: usize = 1;
    for (nums, expected) |next, val| {
        count = lcm(count, next);
        try std.testing.expectEqual(val, count);
    }
}

test "buildGraphAndWalk" {
    const input =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
    ;
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    const directions = iterator.next() orelse return error.TestFailed;
    const contents = iterator.rest();
    var map = Map.init(std.testing.allocator);
    var list = List.init(std.testing.allocator);
    defer map.deinit();
    defer list.deinit();
    try buildGraph(contents, &map, &list);
    const nodes = try findStartingNodes(list.items, map, std.testing.allocator);
    for (nodes) |node| {
        try std.testing.expectEqual(@as(u8, 'A'), node.id[node.id.len - 1]);
    }
    defer std.testing.allocator.free(nodes);
    var count: usize = 1;
    for (nodes) |node| {
        const next = try walk(node, directions);
        count = lcm(count, next);
    }
    try std.testing.expectEqual(@as(usize, 6), count);
}
