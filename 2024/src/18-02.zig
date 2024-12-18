const std = @import("std");
const aoc = @import("aoc.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("18.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input, 70);
    const elapsed = timer.read();

    try stdout.print("{},{}\n", .{ output[0], output[1] });
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8, max_dim: usize) ![2]u16 {
    var map: std.AutoArrayHashMapUnmanaged([2]u16, Status) = .{};
    defer map.deinit(allocator);
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    var simulation: usize = 0;
    var wall: std.ArrayListUnmanaged([2]u16) = .{};
    defer wall.deinit(allocator);
    var edge: std.ArrayListUnmanaged([2]u16) = .{};
    defer edge.deinit(allocator);
    while (true) : (simulation += 1) {
        map.clearRetainingCapacity();
        iterator.reset();
        var last: [2]u16 = undefined;
        for (0..simulation) |_| {
            const line = iterator.next() orelse return error.BadInput;
            const comma = std.mem.indexOfScalar(u8, line, ',') orelse return error.BadInput;
            const x = try std.fmt.parseInt(u16, line[0..comma], 10);
            const y = try std.fmt.parseInt(u16, line[comma + 1 ..], 10);
            try map.put(allocator, .{ x, y }, .obstructed);
            last = .{ x, y };
        }
        for (map.keys()) |key| {
            const ptr = map.getPtr(key).?;
            if (ptr.* == .counted) continue;
            ptr.* = .counted;
            wall.clearRetainingCapacity();
            edge.clearRetainingCapacity();
            try edge.append(allocator, key);
            const directions: []const aoc.Direction = &.{ .north, .east, .south, .west, .northeast, .southeast, .northwest, .southwest };
            while (edge.items.len > 0) {
                const slice = try wall.addManyAsSlice(allocator, edge.items.len);
                @memcpy(slice, edge.items);
                edge.clearRetainingCapacity();
                for (slice) |item| {
                    for (directions) |direction| {
                        const x, const y = direction.walk(item[0], item[1], max_dim, max_dim) catch continue;
                        if (!map.contains(.{ @intCast(x), @intCast(y) })) continue;
                        const status = map.getPtr(.{ @intCast(x), @intCast(y) }).?;
                        if (status.* == .counted) continue;
                        status.* = .counted;
                        try edge.append(allocator, .{ @intCast(x), @intCast(y) });
                    }
                }
            }
            var touches_sides: [4]bool = .{ false, false, false, false };
            for (wall.items) |stone| {
                // left
                if (stone[0] == 0) touches_sides[0] = true;
                // right
                if (stone[0] == max_dim) touches_sides[1] = true;
                // top
                if (stone[1] == 0) touches_sides[2] = true;
                // bottom
                if (stone[1] == max_dim) touches_sides[3] = true;
            }
            if ((touches_sides[0] and (touches_sides[1] or touches_sides[2])) or
                (touches_sides[3] and (touches_sides[1] or touches_sides[2])))
                return last;
        }
    }

    var list: std.ArrayListUnmanaged([2]u16) = .{};
    defer list.deinit(allocator);
    try list.append(allocator, .{ 0, 0 });
    try map.put(allocator, .{ 0, 0 }, .{ .visited = 0 });
    var step: usize = 1;
    while (list.items.len > 0) : (step += 1) {
        const slice = try list.toOwnedSlice(allocator);
        defer allocator.free(slice);
        for (slice) |key| {
            const directions: []const aoc.Direction = &.{ .north, .east, .south, .west };
            for (directions) |direction| {
                const x, const y = direction.walk(key[0], key[1], max_dim, max_dim) catch continue;
                if (!map.contains(.{ @intCast(x), @intCast(y) })) {
                    try list.append(allocator, .{ @intCast(x), @intCast(y) });
                    try map.put(allocator, .{ @intCast(x), @intCast(y) }, .{ .visited = step });
                }
            }
        }
        if (map.contains(.{ @intCast(max_dim), @intCast(max_dim) })) break;
    }

    return map.get(.{ @intCast(max_dim), @intCast(max_dim) }).?.visited;
}

const Status = enum {
    obstructed,
    counted,
};

test {
    const input =
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0
    ;

    const output = try process(std.testing.allocator, input, 6);
    try std.testing.expectEqualSlices(u16, &.{ 6, 1 }, &output);
}
