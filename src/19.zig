const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = try parseArgs(allocator);
    const contents = try getContentsOfFile(allocator, filename);
    allocator.free(filename);

    var map = Map.init(allocator);
    defer map.deinit();
    const key = try parseInput(contents, &map);
    allocator.free(contents);
    const pipe = map.getPtr(key) orelse return error.WalkFailed;
    pipe.visited = true;
    const neighbors = findNeighbors(key, map);
    var forward = map.getPtr(neighbors[0]) orelse return error.WalkFailed;
    var backward = map.getPtr(neighbors[1]) orelse return error.WalkFailed;
    var count: usize = 0;
    var done = false;
    while (!done) : (count += 1) {
        forward.visited = true;
        backward.visited = true;
        const forward_done = try walk(&forward, map);
        const backward_done = try walk(&backward, map);
        done = forward_done or backward_done;
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.NoFilenameGiven;
    return try allocator.dupe(u8, filename);
}

fn getContentsOfFile(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 32 * 1024);
}

const Map = std.HashMap(Key, Pipe, Context, 80);
const Key = struct {
    x: u32,
    y: u32,
};
const Pipe = struct {
    coordinate: Key,
    shape: u8,
    visited: bool,
};
const Context = struct {
    pub fn hash(self: @This(), key: Key) u64 {
        _ = self;
        const shifted: u64 = key.x << 31;
        return shifted + key.y;
    }
    pub fn eql(self: @This(), key: Key, other: Key) bool {
        _ = self;
        return key.x == other.x and key.y == other.y;
    }
};

fn parseInput(input: []const u8, map: *Map) !Key {
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    const key = key: {
        var key: ?Key = null;
        var i: usize = 0;
        while (iterator.next()) |line| : (i += 1) {
            for (line, 0..) |char, j| {
                switch (char) {
                    '|', '-', 'L', 'J', '7', 'F' => {
                        const ptr = try map.getOrPut(.{
                            .x = @intCast(j),
                            .y = @intCast(i),
                        });
                        ptr.value_ptr.* = .{
                            .coordinate = .{
                                .x = @intCast(j),
                                .y = @intCast(i),
                            },
                            .shape = char,
                            .visited = false,
                        };
                    },
                    'S' => {
                        const ptr = try map.getOrPut(.{
                            .x = @intCast(j),
                            .y = @intCast(i),
                        });
                        ptr.value_ptr.* = .{
                            .coordinate = .{
                                .x = @intCast(j),
                                .y = @intCast(i),
                            },
                            .shape = char,
                            .visited = false,
                        };
                        if (key != null) return error.ParseFailed;
                        key = .{ .x = @intCast(j), .y = @intCast(i) };
                    },
                    else => {},
                }
            }
        }
        break :key key orelse return error.ParseFailed;
    };
    return key;
}

fn findNeighbors(key: Key, map: Map) [2]Key {
    var neighbors: [2]Key = undefined;
    var idx: usize = 0;
    const keys: []const Key = &.{
        .{
            .x = key.x -| 1,
            .y = key.y,
        },
        .{ .x = key.x + 1, .y = key.y },
        .{
            .x = key.x,
            .y = key.y -| 1,
        },
        .{
            .x = key.x,
            .y = key.y + 1,
        },
    };
    const shapes: []const []const u8 = &.{
        "-FL", "-7J", "|F7", "|LJ",
    };
    for (keys, shapes) |other, possibilites| {
        if (map.get(other)) |pipe| {
            if (std.mem.indexOfScalar(u8, possibilites, pipe.shape)) |_| {
                neighbors[idx] = other;
                idx += 1;
                if (idx == 2) break;
            }
        }
    }
    return neighbors;
}

fn walk(pipe: **Pipe, map: Map) !bool {
    const curr = pipe.*;
    const neighbors: [2]*Pipe = neighbors: {
        switch (curr.shape) {
            '-' => break :neighbors .{
                map.getPtr(.{
                    .x = curr.coordinate.x -| 1,
                    .y = curr.coordinate.y,
                }) orelse return error.WalkFailed,
                map.getPtr(.{
                    .x = curr.coordinate.x + 1,
                    .y = curr.coordinate.y,
                }) orelse return error.WalkFailed,
            },
            '|' => break :neighbors .{
                map.getPtr(.{
                    .x = curr.coordinate.x,
                    .y = curr.coordinate.y -| 1,
                }) orelse return error.WalkFailed,
                map.getPtr(.{
                    .x = curr.coordinate.x,
                    .y = curr.coordinate.y + 1,
                }) orelse return error.WalkFailed,
            },
            'L' => break :neighbors .{
                map.getPtr(.{
                    .x = curr.coordinate.x,
                    .y = curr.coordinate.y -| 1,
                }) orelse return error.WalkFailed,
                map.getPtr(.{
                    .x = curr.coordinate.x + 1,
                    .y = curr.coordinate.y,
                }) orelse return error.WalkFailed,
            },
            'J' => break :neighbors .{
                map.getPtr(.{
                    .x = curr.coordinate.x -| 1,
                    .y = curr.coordinate.y,
                }) orelse return error.WalkFailed,
                map.getPtr(.{
                    .x = curr.coordinate.x,
                    .y = curr.coordinate.y -| 1,
                }) orelse return error.WalkFailed,
            },
            '7' => break :neighbors .{
                map.getPtr(.{
                    .x = curr.coordinate.x,
                    .y = curr.coordinate.y + 1,
                }) orelse return error.WalkFailed,
                map.getPtr(.{
                    .x = curr.coordinate.x -| 1,
                    .y = curr.coordinate.y,
                }) orelse return error.WalkFailed,
            },
            'F' => break :neighbors .{
                map.getPtr(.{
                    .x = curr.coordinate.x + 1,
                    .y = curr.coordinate.y,
                }) orelse return error.WalkFailed,
                map.getPtr(.{
                    .x = curr.coordinate.x,
                    .y = curr.coordinate.y + 1,
                }) orelse return error.WalkFailed,
            },
            else => return error.WalkFailed,
        }
    };
    for (neighbors) |neighbor| {
        if (!neighbor.visited) {
            pipe.* = neighbor;
            return false;
        }
    }
    return true;
}

test "parseInput and findNeighbors" {
    const input =
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
    ;
    const allocator = std.testing.allocator;
    var map = Map.init(allocator);
    defer map.deinit();
    const key = try parseInput(input, &map);
    try std.testing.expect(Context.eql(.{}, key, .{ .x = 1, .y = 1 }));
    const expected: []const Key = &.{
        .{ .x = 2, .y = 1 }, .{ .x = 1, .y = 2 },
    };
    const neighbors = findNeighbors(key, map);
    for (expected, &neighbors) |value, got| {
        try std.testing.expect(Context.eql(.{}, got, value));
    }
}

test "walk" {
    const input =
        \\7-F7-
        \\.FJ|7
        \\SJLL7
        \\|F--J
        \\LJ.LJ
    ;
    const allocator = std.testing.allocator;
    var map = Map.init(allocator);
    defer map.deinit();
    const key = try parseInput(input, &map);
    const pipe = map.getPtr(key) orelse return error.WalkFailed;
    pipe.visited = true;
    const neighbors = findNeighbors(key, map);
    var forward = map.getPtr(neighbors[0]) orelse return error.WalkFailed;
    var backward = map.getPtr(neighbors[1]) orelse return error.WalkFailed;
    var count: usize = 0;
    var done = false;
    while (!done) : (count += 1) {
        forward.visited = true;
        backward.visited = true;
        const forward_done = try walk(&forward, map);
        const backward_done = try walk(&backward, map);
        done = forward_done or backward_done;
    }
    try std.testing.expectEqual(@as(usize, 8), count);
}
