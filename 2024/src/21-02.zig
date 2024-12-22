const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("21.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input, 25);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}ms\n", .{elapsed / std.time.ns_per_ms});
    try bw.flush();
}

// +---+---+---+
// | 7 | 8 | 9 |
// +---+---+---+
// | 4 | 5 | 6 |
// +---+---+---+
// | 1 | 2 | 3 |
// +---+---+---+
//     | 0 | A |
//     +---+---+

const NumericKeypad = enum(u8) {
    activate = 'A',
    zero = '0',
    one = '1',
    two = '2',
    three = '3',
    four = '4',
    five = '5',
    six = '6',
    seven = '7',
    eight = '8',
    nine = '9',

    fn coordinate(of: NumericKeypad) [2]u8 {
        return switch (of) {
            .activate => .{ 2, 3 },
            .zero => .{ 1, 3 },
            .one => .{ 0, 2 },
            .two => .{ 1, 2 },
            .three => .{ 2, 2 },
            .four => .{ 0, 1 },
            .five => .{ 1, 1 },
            .six => .{ 2, 1 },
            .seven => .{ 0, 0 },
            .eight => .{ 1, 0 },
            .nine => .{ 2, 0 },
        };
    }

    fn validMoves(from: NumericKeypad) []const DirectionalKeypad {
        return @ptrCast(switch (from) {
            .seven => ">v",
            .eight => "<>v",
            .nine => "<v",
            .four => "^>v",
            .five => "<^>v",
            .six => "<^v",
            .one => "^>",
            .two => "<^>v",
            .three => "<^v",
            .zero => "^>",
            .activate => "<^",
        });
    }

    fn dist(from: NumericKeypad, to: NumericKeypad) u8 {
        const a = from.coordinate();
        const b = to.coordinate();
        const x: u16 = @abs(@as(i16, a[0]) - @as(i16, b[0]));
        const y: u16 = @abs(@as(i16, a[1]) - @as(i16, b[1]));
        return @intCast(x + y);
    }

    fn walk(from: NumericKeypad, step: DirectionalKeypad) error{ OutOfBounds, Activate }!NumericKeypad {
        if (step == .activate) return error.Activate;
        return switch (from) {
            .activate => switch (step) {
                .left => .zero,
                .up => .three,
                else => error.OutOfBounds,
            },
            .zero => switch (step) {
                .right => .activate,
                .up => .two,
                else => error.OutOfBounds,
            },
            .one => switch (step) {
                .up => .four,
                .right => .two,
                else => error.OutOfBounds,
            },
            .two => switch (step) {
                .left => .one,
                .up => .five,
                .right => .three,
                .down => .zero,
                else => unreachable,
            },
            .three => switch (step) {
                .left => .two,
                .up => .six,
                .down => .activate,
                else => error.OutOfBounds,
            },
            .four => switch (step) {
                .up => .seven,
                .right => .five,
                .down => .one,
                else => error.OutOfBounds,
            },
            .five => switch (step) {
                .up => .eight,
                .left => .four,
                .right => .six,
                .down => .two,
                else => unreachable,
            },
            .six => switch (step) {
                .left => .five,
                .up => .nine,
                .down => .three,
                else => error.OutOfBounds,
            },
            .seven => switch (step) {
                .right => .eight,
                .down => .four,
                else => error.OutOfBounds,
            },
            .eight => switch (step) {
                .left => .seven,
                .right => .nine,
                .down => .five,
                else => error.OutOfBounds,
            },
            .nine => switch (step) {
                .left => .eight,
                .down => .six,
                else => error.OutOfBounds,
            },
        };
    }

    fn pathFind(from: NumericKeypad, to: NumericKeypad) []const []const DirectionalKeypad {
        const tags = std.meta.tags(NumericKeypad);
        const i = std.mem.indexOfScalar(NumericKeypad, tags, from).?;
        const j = std.mem.indexOfScalar(NumericKeypad, tags, to).?;
        return pairwise_paths[i][j];
    }

    const pairwise_paths: []const []const []const []const DirectionalKeypad = paths: {
        @setEvalBranchQuota(10_000);
        const tags = std.meta.tags(NumericKeypad);
        var paths: []const []const []const []const DirectionalKeypad = &.{};
        for (tags) |from| {
            const acc: []const []const []const DirectionalKeypad = acc: {
                var acc: []const []const []const DirectionalKeypad = &.{};
                for (tags) |to| {
                    const inner: []const []const DirectionalKeypad = blk: {
                        var distance = from.dist(to);
                        const empty: []const []const u8 = &.{""};
                        if (distance == 0) break :blk @ptrCast(empty);
                        var ret: []const []const DirectionalKeypad = &.{};
                        const moves = from.validMoves();
                        for (moves) |move| {
                            const neighbor = from.walk(move) catch unreachable;
                            const slice: []const []const DirectionalKeypad = &.{&.{move}};
                            if (neighbor.dist(to) < distance) ret = ret ++ slice;
                        }
                        distance -= 1;
                        while (distance > 0) : (distance -= 1) {
                            var accum: []const []const DirectionalKeypad = &.{};
                            for (ret) |path| {
                                var curr = from;
                                for (path) |move| {
                                    curr = curr.walk(move) catch unreachable;
                                }
                                const neighbs = curr.validMoves();
                                for (neighbs) |neighb| {
                                    const neighbor = curr.walk(neighb) catch unreachable;
                                    const inner: []const DirectionalKeypad = &.{neighb};
                                    const slice: []const []const DirectionalKeypad = &.{path ++ inner};
                                    if (neighbor.dist(to) < distance) accum = accum ++ slice;
                                }
                            }
                            ret = accum;
                        }
                        break :blk @ptrCast(ret);
                    };
                    const slice: []const []const []const DirectionalKeypad = &.{inner};
                    acc = acc ++ slice;
                }
                break :acc acc;
            };
            const slice: []const []const []const []const DirectionalKeypad = &.{acc};
            paths = paths ++ slice;
        }
        break :paths paths;
    };

    test pathFind {
        const paths: []const []const u8 = &.{
            ">>vvv",
            ">v>vv",
            ">vv>v",
            ">vvv>",
            "v>>vv",
            "v>v>v",
            "v>vv>",
            "vv>>v",
            "vv>v>",
        };
        const got = NumericKeypad.seven.pathFind(.activate);
        try std.testing.expectEqual(paths.len, got.len);
        for (paths, got) |expected, actual| {
            try std.testing.expectEqualStrings(expected, @ptrCast(actual));
        }
    }
};

//     +---+---+
//     | ^ | A |
// +---+---+---+
// | < | v | > |
// +---+---+---+

const DirectionalKeypad = enum(u8) {
    activate = 'A',
    up = '^',
    down = 'v',
    left = '<',
    right = '>',

    fn coordinate(of: DirectionalKeypad) [2]u8 {
        return switch (of) {
            .activate => .{ 2, 0 },
            .up => .{ 1, 0 },
            .left => .{ 0, 1 },
            .down => .{ 1, 1 },
            .right => .{ 2, 1 },
        };
    }

    fn validMoves(from: DirectionalKeypad) []const DirectionalKeypad {
        return @ptrCast(switch (from) {
            .activate => "<v",
            .up => ">v",
            .left => ">",
            .right => "<^",
            .down => "<^>",
        });
    }

    fn walk(from: DirectionalKeypad, step: DirectionalKeypad) error{ Activate, OutOfBounds }!DirectionalKeypad {
        if (step == .activate) return error.Activate;
        return switch (from) {
            .activate => switch (step) {
                .left => .up,
                .down => .right,
                else => error.OutOfBounds,
            },
            .up => switch (step) {
                .right => .activate,
                .down => .down,
                else => error.OutOfBounds,
            },
            .left => switch (step) {
                .right => .down,
                else => error.OutOfBounds,
            },
            .down => switch (step) {
                .left => .left,
                .right => .right,
                .up => .up,
                else => error.OutOfBounds,
            },
            .right => switch (step) {
                .up => .activate,
                .left => .down,
                else => error.OutOfBounds,
            },
        };
    }

    fn dist(from: DirectionalKeypad, to: DirectionalKeypad) u8 {
        const a = from.coordinate();
        const b = to.coordinate();
        const x = @abs(@as(i16, a[0]) - @as(i16, b[0]));
        const y = @abs(@as(i16, a[1]) - @as(i16, b[1]));
        return @intCast(x + y);
    }

    fn pathFind(from: DirectionalKeypad, to: DirectionalKeypad) []const []const DirectionalKeypad {
        const tags = std.meta.tags(DirectionalKeypad);
        const i = std.mem.indexOfScalar(DirectionalKeypad, tags, from).?;
        const j = std.mem.indexOfScalar(DirectionalKeypad, tags, to).?;
        return pairwise_paths[i][j];
    }

    const pairwise_paths: []const []const []const []const DirectionalKeypad = paths: {
        @setEvalBranchQuota(10_000);
        const tags = std.meta.tags(DirectionalKeypad);
        var paths: []const []const []const []const DirectionalKeypad = &.{};
        for (tags) |from| {
            const acc: []const []const []const DirectionalKeypad = acc: {
                var acc: []const []const []const DirectionalKeypad = &.{};
                for (tags) |to| {
                    const inner: []const []const DirectionalKeypad = blk: {
                        var distance = from.dist(to);
                        const empty: []const []const u8 = &.{""};
                        if (distance == 0) break :blk @ptrCast(empty);
                        var ret: []const []const DirectionalKeypad = &.{};
                        const moves = from.validMoves();
                        for (moves) |move| {
                            const neighbor = from.walk(move) catch unreachable;
                            const slice: []const []const DirectionalKeypad = &.{&.{move}};
                            if (neighbor.dist(to) < distance) ret = ret ++ slice;
                        }
                        distance -= 1;
                        while (distance > 0) : (distance -= 1) {
                            var accum: []const []const DirectionalKeypad = &.{};
                            for (ret) |path| {
                                var curr = from;
                                for (path) |move| {
                                    curr = curr.walk(move) catch unreachable;
                                }
                                const neighbs = curr.validMoves();
                                for (neighbs) |neighb| {
                                    const neighbor = curr.walk(neighb) catch unreachable;
                                    const inner: []const DirectionalKeypad = &.{neighb};
                                    const slice: []const []const DirectionalKeypad = &.{path ++ inner};
                                    if (neighbor.dist(to) < distance) accum = accum ++ slice;
                                }
                            }
                            ret = accum;
                        }
                        break :blk @ptrCast(ret);
                    };
                    const slice: []const []const []const DirectionalKeypad = &.{inner};
                    acc = acc ++ slice;
                }
                break :acc acc;
            };
            const slice: []const []const []const []const DirectionalKeypad = &.{acc};
            paths = paths ++ slice;
        }
        break :paths paths;
    };

    test pathFind {
        const expected: []const []const u8 = &.{
            ">^>",
            ">>^",
        };
        const got = DirectionalKeypad.left.pathFind(.activate);
        try std.testing.expectEqual(expected.len, got.len);
        for (expected, got) |string, slice| {
            try std.testing.expectEqualStrings(string, @ptrCast(slice));
        }
    }
};

fn joinWithActivateSeparator(allocator: std.mem.Allocator, chunks: []const []const DirectionalKeypad) std.mem.Allocator.Error![]DirectionalKeypad {
    if (chunks.len == 0) return &.{};
    var len: usize = chunks.len;
    for (chunks) |chunk| len += chunk.len;
    const buf = try allocator.alloc(DirectionalKeypad, len);
    var idx: usize = 0;
    for (chunks) |chunk| {
        @memcpy(buf[idx..][0..chunk.len], chunk);
        buf[idx + chunk.len] = .activate;
        idx += chunk.len + 1;
    }
    return buf;
}

test joinWithActivateSeparator {
    const expected = "<A^AA>^^AvvvA";
    const got = try joinWithActivateSeparator(std.testing.allocator, &.{
        &.{.left}, &.{.up}, &.{}, &.{ .right, .up, .up }, &.{ .down, .down, .down },
    });
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, @ptrCast(got));
}

fn Combinations(comptime T: type) type {
    return struct {
        data: []const []const T,
        index: usize,
        length: usize,

        const Self = @This();

        pub fn init(data: []const []const T) Self {
            var length: usize = 1;
            for (data) |datum| length *= @max(datum.len, 1);
            return .{
                .data = data,
                .index = 0,
                .length = length,
            };
        }

        pub fn next(self: *Self, allocator: std.mem.Allocator) !?[]const T {
            if (self.index >= self.length) return null;
            const slice = try allocator.alloc(T, self.data.len);
            var max: usize = 1;
            for (slice, self.data) |*ptr, datum| {
                const j = @divTrunc(self.index, max);
                max *= @max(datum.len, 1);
                if (datum.len > 0) ptr.* = datum[j % datum.len] else ptr.* = &.{};
            }
            self.index += 1;
            return slice;
        }
    };
}

test Combinations {
    const data: []const []const []const u8 = &.{
        &.{ "a", "aa", "aaa" },
        &.{&.{}},
        &.{},
        &.{"b"},
        &.{ "c", "cc" },
    };
    var combinations = Combinations([]const u8).init(data);
    const expected: []const []const u8 = &.{
        "abc", "aabc", "aaabc", "abcc", "aabcc", "aaabcc",
    };
    var list: std.ArrayListUnmanaged([]const u8) = .{};
    defer list.deinit(std.testing.allocator);
    defer for (list.items) |item| std.testing.allocator.free(item);
    while (try combinations.next(std.testing.allocator)) |combination| {
        defer std.testing.allocator.free(combination);
        try list.append(std.testing.allocator, try std.mem.concat(std.testing.allocator, u8, combination));
    }
    try std.testing.expectEqual(expected.len, list.items.len);
    for (expected, list.items) |expectation, got| try std.testing.expectEqualStrings(expectation, got);
}

const Cache = std.AutoHashMapUnmanaged(struct { DirectionalKeypad, DirectionalKeypad, usize }, usize);

fn prepCache(allocator: std.mem.Allocator, cache: *Cache, start: DirectionalKeypad, end: DirectionalKeypad, level: usize) !void {
    if (cache.contains(.{ start, end, level })) return;
    if (level == 1) return {
        // to move the robot from start to end, the controller makes
        // one press for each unit of distance plus activate
        try cache.put(allocator, .{ start, end, level }, start.dist(end) + 1);
    };
    // these are the paths that the robot can take
    const seg = start.pathFind(end);
    var length: usize = std.math.maxInt(usize);
    var list: std.ArrayListUnmanaged([]const []const DirectionalKeypad) = .{};
    defer list.deinit(allocator);
    for (seg) |path| {
        list.clearRetainingCapacity();
        // the controller's controller must move the controller to each button in sequence
        var controller_start: DirectionalKeypad = .activate;
        var len: usize = 0;
        for (path) |controller_end| {
            try prepCache(allocator, cache, controller_start, controller_end, level - 1);
            len += cache.get(.{ controller_start, controller_end, level - 1 }).?;
            controller_start = controller_end;
        }
        try prepCache(allocator, cache, controller_start, .activate, level - 1);
        len += cache.get(.{ controller_start, .activate, level - 1 }).?;
        length = @min(len, length);
    }
    try cache.put(allocator, .{ start, end, level }, length);
}

test prepCache {
    var cache: Cache = .{};
    defer cache.deinit(std.testing.allocator);
    var list: [3]usize = undefined;
    for (&list, 1..) |*item, i| {
        try prepCache(std.testing.allocator, &cache, .activate, .left, i);
        item.* = cache.get(.{ .activate, .left, i }).?;
    }
    const expected: []const usize = &.{ 4, 10, 26 };
    try std.testing.expectEqualSlices(usize, expected, &list);
}

fn calcLength(allocator: std.mem.Allocator, line: []const u8, level: usize, cache: *Cache) !u64 {
    var length: usize = std.math.maxInt(usize);
    var num_start: NumericKeypad = .activate;
    const segments = try allocator.alloc([]const []const DirectionalKeypad, line.len);
    defer allocator.free(segments);
    for (line, segments) |byte, *seg| {
        const end: NumericKeypad = @enumFromInt(byte);
        seg.* = num_start.pathFind(end);
        num_start = end;
    }
    var combinations = Combinations([]const DirectionalKeypad).init(segments);
    while (try combinations.next(allocator)) |selection| {
        defer allocator.free(selection);
        const path = try joinWithActivateSeparator(allocator, selection);
        defer allocator.free(path);
        var len: usize = 0;
        var start: DirectionalKeypad = .activate;
        for (path) |end| {
            try prepCache(allocator, cache, start, end, level);
            const increase = cache.get(.{ start, end, level }).?;
            len += increase;
            start = end;
        }
        length = @min(len, length);
    }
    return length;
}

test calcLength {
    var cache: Cache = .{};
    defer cache.deinit(std.testing.allocator);
    const l = try calcLength(std.testing.allocator, "0", 2, &cache);
    try std.testing.expectEqual(18, l);
}

fn process(allocator: std.mem.Allocator, input: []const u8, level: usize) !u64 {
    var count: u64 = 0;
    var cache: Cache = .{};
    defer cache.deinit(allocator);
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        const multiplier = try std.fmt.parseInt(u64, line[0 .. line.len - 1], 10);
        count += (try calcLength(allocator, line, level, &cache)) * multiplier;
    }
    return count;
}

comptime {
    _ = NumericKeypad;
    _ = DirectionalKeypad;
}

test {
    std.testing.log_level = .debug;
    // if (true) return error.SkipZigTest;
    const input =
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
    ;
    const output = try process(std.testing.allocator, input, 2);
    try std.testing.expectEqual(126384, output);
}
