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
    const node = map.getPtr("AAA") orelse return error.NodeMissing;
    const count = try walk(node, directions);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn walk(node: *Node, directions: []const u8) !usize {
    var done = false;
    var count: usize = 0;
    var current: *Node = node;
    while (!done) {
        for (directions) |direction| {
            count += 1;
            switch (direction) {
                'L' => current = current.left,
                'R' => current = current.right,
                else => return error.UnexpectedDirection,
            }
            done = std.mem.eql(u8, current.id, "ZZZ");
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

test "buildGraphAndWalk" {
    const input =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;
    const keys: []const []const u8 = &.{ "AAA", "BBB", "CCC", "DDD", "EEE", "GGG", "ZZZ" };
    const lefts: []const []const u8 = &.{ "BBB", "DDD", "ZZZ", "DDD", "EEE", "GGG", "ZZZ" };
    const rights: []const []const u8 = &.{ "CCC", "EEE", "GGG", "DDD", "EEE", "GGG", "ZZZ" };
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    const directions = iterator.next() orelse return error.TestFailed;
    const contents = iterator.rest();
    var map = Map.init(std.testing.allocator);
    var list = List.init(std.testing.allocator);
    defer map.deinit();
    defer list.deinit();
    try buildGraph(contents, &map, &list);
    for (keys, lefts, rights) |key, left, right| {
        const node = map.get(key) orelse return error.TestFailed;
        try std.testing.expectEqualStrings(key, node.id);
        try std.testing.expectEqualStrings(left, node.left.id);
        try std.testing.expectEqualStrings(right, node.right.id);
    }
    const node = map.getPtr("AAA") orelse return error.TestFailed;
    const count = try walk(node, directions);
    try std.testing.expectEqual(@as(usize, 2), count);
}
