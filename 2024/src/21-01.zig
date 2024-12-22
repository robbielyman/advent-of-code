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

    const output = try process(allocator, input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{elapsed / std.time.ns_per_us});
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

    fn walk(start: NumericKeypad, instruction: DirectionalKeypad) error{ Activate, OutOfBounds }!NumericKeypad {
        if (instruction == .activate) return error.Activate;
        return switch (start) {
            .activate => switch (instruction) {
                .up => .three,
                .left => .zero,
                else => error.OutOfBounds,
            },
            .zero => switch (instruction) {
                .up => .two,
                .right => .activate,
                else => error.OutOfBounds,
            },
            .one => switch (instruction) {
                .up => .four,
                .right => .two,
                else => error.OutOfBounds,
            },
            .two => switch (instruction) {
                .left => .one,
                .up => .five,
                .right => .three,
                .down => .zero,
                else => unreachable,
            },
            .three => switch (instruction) {
                .left => .two,
                .up => .six,
                .down => .activate,
                else => error.OutOfBounds,
            },
            .four => switch (instruction) {
                .up => .seven,
                .right => .five,
                .down => .one,
                else => error.OutOfBounds,
            },
            .five => switch (instruction) {
                .left => .four,
                .up => .eight,
                .right => .six,
                .down => .two,
                else => unreachable,
            },
            .six => switch (instruction) {
                .left => .five,
                .up => .nine,
                .down => .three,
                else => error.OutOfBounds,
            },
            .seven => switch (instruction) {
                .right => .eight,
                .down => .four,
                else => error.OutOfBounds,
            },
            .eight => switch (instruction) {
                .left => .seven,
                .right => .nine,
                .down => .five,
                else => error.OutOfBounds,
            },
            .nine => switch (instruction) {
                .left => .eight,
                .down => .six,
                else => error.OutOfBounds,
            },
        };
    }

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

    fn distance(a: NumericKeypad, b: NumericKeypad) u8 {
        const a_coord = a.coordinate();
        const b_coord = b.coordinate();
        const d_x: u16 = @abs(@as(i16, a_coord[0]) - @as(i16, b_coord[0]));
        const d_y: u16 = @abs(@as(i16, a_coord[1]) - @as(i16, b_coord[1]));
        return @intCast(d_x + d_y);
    }

    const Navigator = std.AutoHashMapUnmanaged([2]NumericKeypad, []const []const DirectionalKeypad);

    fn validMoves(from: NumericKeypad) []const DirectionalKeypad {
        return @ptrCast(switch (from) {
            .activate => "<^",
            .zero => "^>",
            .one => ">^",
            .two => "<^>v",
            .three => "<^v",
            .four => "^>v",
            .five => "<^>v",
            .six => "<^v",
            .seven => ">v",
            .eight => "<>v",
            .nine => "<v",
        });
    }

    fn populateShortestPathsBetween(start: NumericKeypad, end: NumericKeypad, arena: std.mem.Allocator, robot_plans: *Navigator) !void {
        if (robot_plans.contains(.{ start, end })) return;
        const dist = start.distance(end);
        if (dist == 0) {
            try robot_plans.put(arena, .{ start, end }, &.{});
            return;
        }
        var list: std.ArrayListUnmanaged([]DirectionalKeypad) = .{};
        defer list.deinit(arena);
        const moves = start.validMoves();
        for (moves) |move| {
            const neighbor = start.walk(move) catch unreachable;
            if (neighbor.distance(end) >= dist) continue;
            try neighbor.populateShortestPathsBetween(end, arena, robot_plans);
            const paths_starting_at_neighbor = robot_plans.get(.{ neighbor, end }).?;
            if (paths_starting_at_neighbor.len == 0) {
                try list.append(arena, try arena.dupe(DirectionalKeypad, &.{move}));
                continue;
            }
            const slices = try list.addManyAsSlice(arena, paths_starting_at_neighbor.len);
            for (paths_starting_at_neighbor, slices) |path, *slice| {
                slice.* = try arena.alloc(DirectionalKeypad, dist);
                slice.*[0] = move;
                @memcpy(slice.*[1..], path);
            }
        }
        try robot_plans.put(arena, .{ start, end }, try list.toOwnedSlice(arena));
    }

    test populateShortestPathsBetween {
        const paths: []const []const u8 = &.{
            "^^^<<",
            "^^<^<",
            "^^<<^",
            "^<^^<",
            "^<^<^",
            "^<<^^",
            "<^^^<",
            "<^^<^",
            "<^<^^",
        };
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var navigator: Navigator = .{};
        defer navigator.deinit(arena.allocator());
        try NumericKeypad.activate.populateShortestPathsBetween(.seven, arena.allocator(), &navigator);
        const got = navigator.get(.{ .activate, .seven }).?;
        try std.testing.expectEqual(paths.len, got.len);
        for (got) |path| {
            const string: []const u8 = @ptrCast(path);
            for (paths) |expected| {
                if (std.mem.eql(u8, expected, string)) break;
            } else {
                std.log.err("{s}", .{string});
            }
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

    fn walk(start: DirectionalKeypad, instruction: DirectionalKeypad) error{ Activate, OutOfBounds }!DirectionalKeypad {
        if (instruction == .activate) return error.Activate;
        return switch (start) {
            .activate => switch (instruction) {
                .left => .up,
                .down => .right,
                else => error.OutOfBounds,
            },
            .up => switch (instruction) {
                .right => .activate,
                .down => .down,
                else => error.OutOfBounds,
            },
            .left => switch (instruction) {
                .right => .down,
                else => error.OutOfBounds,
            },
            .down => switch (instruction) {
                .left => .left,
                .up => .up,
                .right => .right,
                else => error.OutOfBounds,
            },
            .right => switch (instruction) {
                .up => .activate,
                .left => .down,
                else => error.OutOfBounds,
            },
        };
    }

    fn coordinate(of: DirectionalKeypad) [2]u8 {
        return switch (of) {
            .activate => .{ 2, 0 },
            .up => .{ 1, 0 },
            .left => .{ 0, 1 },
            .down => .{ 1, 1 },
            .right => .{ 2, 1 },
        };
    }

    fn distance(a: DirectionalKeypad, b: DirectionalKeypad) u8 {
        const a_coord = a.coordinate();
        const b_coord = b.coordinate();
        const d_x: u16 = @abs(@as(i16, a_coord[0]) - @as(i16, b_coord[0]));
        const d_y: u16 = @abs(@as(i16, a_coord[1]) - @as(i16, b_coord[1]));
        return @intCast(d_x + d_y);
    }

    const Navigator = std.AutoHashMapUnmanaged([2]DirectionalKeypad, []const []const DirectionalKeypad);

    fn validMoves(from: DirectionalKeypad) []const DirectionalKeypad {
        return @ptrCast(switch (from) {
            .activate => "<v",
            .up => ">v",
            .left => ">",
            .down => "<^>",
            .right => "<^",
        });
    }

    fn populateShortestPathsBetween(start: DirectionalKeypad, end: DirectionalKeypad, arena: std.mem.Allocator, robot_plans: *Navigator) !void {
        if (robot_plans.contains(.{ start, end })) return;
        const dist = start.distance(end);
        if (dist == 0) {
            try robot_plans.put(arena, .{ start, end }, &.{});
            return;
        }
        var list: std.ArrayListUnmanaged([]DirectionalKeypad) = .{};
        defer list.deinit(arena);
        const moves = start.validMoves();
        for (moves) |move| {
            const neighbor = start.walk(move) catch unreachable;
            if (neighbor.distance(end) >= dist) continue;
            try neighbor.populateShortestPathsBetween(end, arena, robot_plans);
            const paths_starting_at_neighbor = robot_plans.get(.{ neighbor, end }).?;
            if (paths_starting_at_neighbor.len == 0) {
                try list.append(arena, try arena.dupe(DirectionalKeypad, &.{move}));
                continue;
            }
            const slices = try list.addManyAsSlice(arena, paths_starting_at_neighbor.len);
            for (paths_starting_at_neighbor, slices) |path, *slice| {
                slice.* = try arena.alloc(DirectionalKeypad, dist);
                slice.*[0] = move;
                @memcpy(slice.*[1..], path);
            }
        }
        try robot_plans.put(arena, .{ start, end }, try list.toOwnedSlice(arena));
    }

    test populateShortestPathsBetween {
        const paths: []const []const u8 = &.{ ">>^", ">^>" };
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var navigator: Navigator = .{};
        defer navigator.deinit(arena.allocator());
        try DirectionalKeypad.left.populateShortestPathsBetween(.activate, arena.allocator(), &navigator);
        const got = navigator.get(.{ .left, .activate }).?;
        try std.testing.expectEqual(paths.len, got.len);
        for (got) |path| {
            const string: []const u8 = @ptrCast(path);
            for (paths) |expected| {
                if (std.mem.eql(u8, expected, string)) break;
            } else {
                std.log.err("{s}", .{string});
            }
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

fn combine(allocator: std.mem.Allocator, subpaths: []const []const []const DirectionalKeypad) ![]const []const DirectionalKeypad {
    var combinations = Combinations([]const DirectionalKeypad).init(subpaths);
    var list: std.ArrayListUnmanaged([]const DirectionalKeypad) = .{};
    while (try combinations.next(allocator)) |combination| {
        defer allocator.free(combination);
        try list.append(allocator, try joinWithActivateSeparator(allocator, combination));
    }
    return try list.toOwnedSlice(allocator);
}

test combine {
    // if (true) return error.SkipZigTest;
    const paths: []const []const u8 = &.{
        "<A^AA>^^AvvvA",
        "<A^AA^>^AvvvA",
        "<A^AA^^>AvvvA",
    };
    const combined = try combine(std.testing.allocator, &.{
        &.{&.{.left}},
        &.{&.{.up}},
        &.{},
        &.{ &.{ .right, .up, .up }, &.{ .up, .right, .up }, &.{ .up, .up, .right } },
        &.{&.{ .down, .down, .down }},
    });
    defer std.testing.allocator.free(combined);
    defer for (combined) |combination| std.testing.allocator.free(combination);
    try std.testing.expectEqual(paths.len, combined.len);
    for (paths, combined) |path, combination| {
        try std.testing.expectEqualStrings(path, @ptrCast(combination));
    }
}

fn process(allocator: std.mem.Allocator, input: []const u8) !u64 {
    // var logger: std.ArrayListUnmanaged(u8) = .{};
    // defer logger.deinit(allocator);
    // var writer = logger.writer(allocator);
    var count: u64 = 0;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const child = arena.allocator();

    var numeric_keypad: NumericKeypad.Navigator = .{};
    for (std.meta.tags(NumericKeypad)) |start| {
        for (std.meta.tags(NumericKeypad)) |end| {
            try start.populateShortestPathsBetween(end, child, &numeric_keypad);
        }
    }
    var directional_keypad: DirectionalKeypad.Navigator = .{};
    for (std.meta.tags(DirectionalKeypad)) |start| {
        for (std.meta.tags(DirectionalKeypad)) |end| {
            try start.populateShortestPathsBetween(end, child, &directional_keypad);
        }
    }

    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    var list: std.ArrayListUnmanaged([]const []const DirectionalKeypad) = .{};
    var list_of_lists: std.ArrayListUnmanaged([]const DirectionalKeypad) = .{};
    while (iterator.next()) |line| {
        const multiplier = try std.fmt.parseInt(u64, line[0 .. line.len - 1], 10);
        const depressurized = depressurized: {
            var start: NumericKeypad = .activate;
            list.clearRetainingCapacity();
            for (line) |end_byte| {
                const end: NumericKeypad = @enumFromInt(end_byte);
                try list.append(child, numeric_keypad.get(.{ start, end }).?);
                start = end;
            }
            break :depressurized try combine(child, list.items);
        };
        list_of_lists.clearRetainingCapacity();
        for (depressurized) |depress| {
            {
                var start: DirectionalKeypad = .activate;
                list.clearRetainingCapacity();
                for (depress) |end| {
                    const movement = directional_keypad.get(.{ start, end }).?;
                    try list.append(child, movement);
                    start = end;
                }
            }
            const combined = try combine(child, list.items);
            if (list_of_lists.items.len > 0 and list_of_lists.items[0].len > combined[0].len) {
                list_of_lists.clearRetainingCapacity();
            }
            const slice = try list_of_lists.addManyAsSlice(child, combined.len);
            @memcpy(slice, combined);
        }
        const irradiated = try list_of_lists.toOwnedSlice(child);
        for (irradiated) |radiate| {
            {
                var start: DirectionalKeypad = .activate;
                list.clearRetainingCapacity();
                for (radiate) |end| {
                    const movement = directional_keypad.get(.{ start, end }).?;
                    try list.append(child, movement);
                    start = end;
                }
            }
            const combined = try combine(child, list.items);
            if (list_of_lists.items.len > 0 and list_of_lists.items[0].len > combined[0].len) {
                list_of_lists.clearRetainingCapacity();
            }
            const slice = try list_of_lists.addManyAsSlice(child, combined.len);
            @memcpy(slice, combined);
        }
        const historians = try list_of_lists.toOwnedSlice(child);
        for (historians, 0..) |historian, i| {
            var found = false;
            for (historians[0..i]) |prior| {
                if (std.mem.eql(DirectionalKeypad, historian, prior)) found = true;
            }
            if (found) continue;
            const string: []const u8 = @ptrCast(historian);
            std.debug.print("{s}\n", .{string});
        }
        std.debug.print("\n", .{});
        count += historians[0].len * multiplier;
    }
    // std.log.debug("{s}", .{logger.items});
    return count;
}

comptime {
    _ = NumericKeypad;
    _ = DirectionalKeypad;
    _ = combine;
    _ = joinWithActivateSeparator;
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
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(126384, output);
}
