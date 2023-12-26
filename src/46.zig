const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const map = map: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :map try getContentsOfFile(filename, allocator);
    };
    defer {
        for (map) |m| allocator.free(m);
        allocator.free(map);
    }
    var hash = Map.init(allocator);
    defer hash.deinit();

    try hash.put(.{ .x = 1, .y = 0 }, .{
        .done = .{ true, true, false, true },
    });

    while (try buildGraph(map, &hash)) {}

    std.debug.print("graph built!\n", .{});

    const count = try findLongestPath(hash, allocator, .{
        .y = map.len - 1,
        .x = map[map.len - 1].len - 2,
    });

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{
        @divTrunc( timer.read(), std.time.ns_per_ms)
    });
    try bw.flush();
}

fn getContentsOfFile(filename: []const u8, allocator: std.mem.Allocator) ![]const []const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    const reader = file.reader();
    var list = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (list.items) |i| allocator.free(i);
        list.deinit();
    }
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var done = false;
    while (!done) {
        defer buffer.clearRetainingCapacity();
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        if (buffer.items.len > 0) {
            const line = try list.addOne();
            line.* = try allocator.dupe(u8, buffer.items);
        }
    }
    return try list.toOwnedSlice();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.NoFilename;
    return try allocator.dupe(u8, filename);
}

const Key = struct {
    x: usize,
    y: usize,
};
const Map = std.AutoArrayHashMap(Key, Node);
const Node = struct {
    children: [4]?Key = .{ null, null, null, null },
    lengths: [4]?usize = .{ null, null, null, null },
    done: [4]bool,
};
const Direction = enum(usize) {
    North,
    East,
    South,
    West,
    const array: [4]Direction = .{
        .North, .East, .South, .West,
    };
};

fn buildGraph(map: []const []const u8, hash: *Map) !bool {
    for (hash.keys()) |key| {
        const node = hash.get(key).?;
        for (node.done, 0..) |done, i| {
            if (done) continue;
            const new_key, const len = try walkToNextNode(map, key, hash, Direction.array[i]);
            const reget = hash.getPtr(key).?;
            reget.children[i] = new_key orelse return error.DeadEnd;
            reget.lengths[i] = len;
            reget.done[i] = true;
            return true;
        }
    }
    return false;
}

fn walkToNextNode(
    map: []const []const u8,
    key: Key,
    hash: *Map,
    d: Direction,
) !struct { ?Key, usize } {
    const old_dir: [4]Direction = .{
        .South, .West, .North, .East,
    };
    var forward = d;
    var backward = old_dir[@intFromEnum(forward)];
    var loc: Key = switch (forward) {
        .North => .{ .x = key.x, .y = key.y - 1 },
        .South => .{ .x = key.x, .y = key.y + 1 },
        .East => .{ .x = key.x + 1, .y = key.y },
        .West => .{ .x = key.x - 1, .y = key.y },
    };
    std.debug.assert(map[loc.y][loc.x] != '#');
    var len: usize = 1;
    const retloc: ?Key = retloc: {
        while (true) : (len += 1) {
            if (loc.y == map.len - 1) {
                try hash.put(loc, .{
                    .children = .{ null, null, null, null },
                    .done = .{ false, true, true, true },
                    .lengths = .{ null, null, null, null },
                });
                break :retloc loc;
            }
            if (loc.y == 0) break :retloc loc;
            const neighbors: [4]Key = .{
                .{ .x = loc.x, .y = loc.y - 1 },
                .{ .x = loc.x + 1, .y = loc.y },
                .{ .x = loc.x, .y = loc.y + 1 },
                .{ .x = loc.x - 1, .y = loc.y },
            };
            var node: Node = .{
                .children = .{ null, null, null, null },
                .done = .{ true, true, true, true },
                .lengths = .{ null, null, null, null },
            };
            var count: usize = 0;
            inline for (neighbors, Direction.array, 0..) |n, dir, i| {
                if (map[n.y][n.x] != '#') {
                    count += 1;
                    node.done[i] = false;
                    if (backward != dir) forward = dir;
                }
            }
            if (count > 2) {
                const res = try hash.getOrPut(loc);
                if (!res.found_existing) res.value_ptr.* = node;
                break :retloc loc;
            }
            if (count == 1) {
                std.debug.print("{any}\n", .{loc});
                break :retloc null;
            }
            loc = neighbors[@intFromEnum(forward)];
            backward = old_dir[@intFromEnum(forward)];
        }
    };

    return .{ retloc, len };
}

test "buildGraph" {
    std.testing.log_level = .info;
    const input =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.....###.#.###
        \\###.#####.#.#.###.#.###
        \\###.....#.#.#.....#...#
        \\###.###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########.#
        \\#.#...#...#...###.....#
        \\#.#.#.#######.###.###.#
        \\#...#...#.......#.###.#
        \\#####.#.#.###.#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###.#####.###
        \\#...#...#.#.....#...###
        \\#.###.###.#.###.#.#.###
        \\#.....###...###...#...#
        \\#####################.#
    ;
    const allocator = std.testing.allocator;
    const map = map: {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();
        var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
        while (tokenizer.next()) |token| {
            try list.append(token);
        }
        break :map try list.toOwnedSlice();
    };
    defer allocator.free(map);

    var hash = Map.init(allocator);
    defer hash.deinit();
    
    try hash.put(.{
        .x = 1,
        .y = 0,
    }, .{
        .children = .{ null, null, undefined, null },
        .lengths = .{ null, null, 1, null },
        .done = .{ true, true, false, true },
    });
    
    while (try buildGraph(map, &hash)) {}

    try std.testing.expectEqual(@as(usize, 154), try findLongestPath(hash, allocator, .{
        .x = map[map.len - 1].len - 2,
        .y = map.len - 1,
        }));
}

const Queue = std.PriorityQueue(Path, void, Path.compareFn);

const Path = struct {
    visited: []const Key,
    len: usize,

    fn compareFn(context: void, a: Path, b:Path) std.math.Order {
        _ = context;
        if (a.len > b.len) return .lt;
        if (a.len < b.len) return .gt;
        return .eq;
    }
};

fn findLongestPath(hash: Map, allocator: std.mem.Allocator, final: Key) !usize {
    var longest: usize = 0;
    var queue = Queue.init(allocator, {});
    defer queue.deinit();
    const visited = try allocator.dupe(Key, &.{ .{.x = 1, .y = 0 } });
    try queue.add(.{
        .visited = visited,
        .len = 0,
    });
    while (queue.removeOrNull()) |path| {
        const last = path.visited[path.visited.len - 1];
        if (last.x == final.x and last.y == final.y) {
            longest = @max(longest, path.len);
        } else {
            defer allocator.free(path.visited);
            const node = hash.get(last).?;
            for (node.children, node.lengths) |child, length| {
                if (child == null) continue;
                if (findKey(path.visited, child.?) != null) continue;
                const new = try allocator.alloc(Key, path.visited.len + 1);
                @memcpy(new[0..path.visited.len], path.visited);
                new[path.visited.len] = child.?;
                try queue.add(.{
                    .visited = new,
                    .len = path.len + length.?,
                });
            }
        }
    }
    return longest;
}

fn findKey(haystack: []const Key, needle: Key) ?usize {
    for (haystack, 0..) |other, i| {
        if (needle.y == other.y and needle.x == other.x) return i;
    }
    return null;
}
