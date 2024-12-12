const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("12.txt", .{});
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
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var count: usize = 0;
    const max_x, const max_y = aoc.dimensions(input);
    var visited: std.AutoArrayHashMapUnmanaged([2]u16, void) = .{};
    defer visited.deinit(allocator);
    var map: std.AutoArrayHashMapUnmanaged([2]u16, void) = .{};
    defer map.deinit(allocator);
    const directions: []const aoc.Direction = &.{ .north, .east, .south, .west };
    var perimeter: std.AutoArrayHashMapUnmanaged([2]u16, [4]Fence) = .{};
    defer perimeter.deinit(allocator);

    var idx: usize = 0;
    while (idx < input.len) : (idx += 1) {
        const i_coord = aoc.indexToCoordinates(idx, input.len, max_x + 1) catch |err| switch (err) {
            error.Delimiter => continue,
            error.Overflow => unreachable,
        };
        if (visited.get(.{ @intCast(i_coord[0]), @intCast(i_coord[1]) })) |_| continue;
        const value = input[idx];
        var area: usize = 0;
        perimeter.clearRetainingCapacity();
        var slice = try allocator.alloc([2]u16, 1);
        defer allocator.free(slice);
        slice[0] = .{ @intCast(i_coord[0]), @intCast(i_coord[1]) };
        while (slice.len > 0) {
            map.clearRetainingCapacity();
            for (slice) |coord| {
                area += 1;
                try visited.put(allocator, coord, {});
                var sides: [4]Fence = .{.none} ** 4;
                for (directions, 0..) |direction, i| {
                    const x, const y = direction.walk(coord[0], coord[1], max_x - 1, max_y - 1) catch {
                        sides[i] = .present;
                        continue;
                    };
                    const offset = aoc.coordinatesToIndex(x, y, max_x, max_y) catch unreachable;
                    if (input[offset] == value) {
                        if (visited.get(.{ @intCast(x), @intCast(y) }) == null)
                            try map.put(allocator, .{ @intCast(x), @intCast(y) }, {});
                    } else sides[i] = .present;
                }
                if (!std.mem.eql(Fence, &sides, &.{ .none, .none, .none, .none })) {
                    try perimeter.put(allocator, coord, sides);
                }
            }
            allocator.free(slice);
            slice = try allocator.dupe([2]u16, map.keys());
        }
        var sides: usize = 0;
        for (perimeter.keys()) |key| {
            const val = perimeter.getPtr(key).?;
            var i: usize = 0;
            while (std.mem.indexOfScalarPos(Fence, val, i, .present)) |side| {
                i = side + 1;
                var kv: KV = .{ .key = key, .val = val };
                val[side] = .counted;
                sides += 1;
                while (kv.next(&perimeter, @enumFromInt(side), .cw)) |n_kv| {
                    kv = n_kv;
                    kv.val[side] = .counted;
                }
                kv = .{ .key = key, .val = val };
                while (kv.next(&perimeter, @enumFromInt(side), .ccw)) |n_kv| {
                    kv = n_kv;
                    kv.val[side] = .counted;
                }
            }
        }
        count += area * sides;
    }
    return count;
}

const KV = struct {
    key: [2]u16,
    val: *[4]Fence,

    pub fn format(self: KV, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("boundary: ({}, {}): ", .{ self.key[0], self.key[1] });
        for (0..4) |i| if (self.val[i] != .none) {
            const fence: KV.Side = @enumFromInt(i);
            try writer.print("{s}, ", .{@tagName(fence)});
        };
    }

    const Side = enum {
        north,
        east,
        south,
        west,
        fn turn(side: Side, curl: Curl) Side {
            return switch (side) {
                .north => switch (curl) {
                    .cw => .east,
                    .ccw => .west,
                },
                .east => switch (curl) {
                    .cw => .south,
                    .ccw => .north,
                },
                .south => switch (curl) {
                    .cw => .west,
                    .ccw => .east,
                },
                .west => switch (curl) {
                    .cw => .north,
                    .ccw => .south,
                },
            };
        }
    };
    const Curl = enum { cw, ccw };

    fn next(kv: KV, map: *const std.AutoArrayHashMapUnmanaged([2]u16, [4]Fence), side: Side, direction: Curl) ?KV {
        const x, const y = kv.key;
        if (kv.val[@intFromEnum(side.turn(direction))] != .none) return null;
        const next_key: [2]u16 = switch (side) {
            .north => switch (direction) {
                .cw => .{ x +| 1, y },
                .ccw => .{ x -| 1, y },
            },
            .east => switch (direction) {
                .cw => .{ x, y +| 1 },
                .ccw => .{ x, y -| 1 },
            },
            .south => switch (direction) {
                .cw => .{ x -| 1, y },
                .ccw => .{ x +| 1, y },
            },
            .west => switch (direction) {
                .cw => .{ x, y -| 1 },
                .ccw => .{ x, y +| 1 },
            },
        };
        if (x == next_key[0] and y == next_key[1]) return null;
        const ptr = map.getPtr(next_key) orelse return null;
        if (ptr[@intFromEnum(side)] != .present) return null;
        return .{ .key = next_key, .val = ptr };
    }
};

const Fence = enum { none, present, counted };

test {
    const input =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(1206, output);
}
