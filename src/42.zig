const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = contents: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :contents try getContents(filename, allocator);
    };
    defer allocator.free(contents);

    const map, const start: Point = map: {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();
        var coord: [2]?usize = .{ null, null };
        var tokenizer = std.mem.tokenizeScalar(u8, contents, '\n');
        var y: usize = 0;
        while (tokenizer.next()) |line| : (y += 1) {
            try list.append(line);
            for (line, 0..) |char, x| {
                if (char == 'S') coord = .{ x, y };
            }
        }
        break :map .{ try list.toOwnedSlice(), .{ .x = @intCast(coord[0].?), .y = @intCast(coord[1].?) } };
    };
    defer allocator.free(map);

    const og = try takeSteps(start, 65 + (131 * 3), map, allocator);
    
    const a1 = try takeSteps(start, 65, map, allocator);
    const a2 = try takeSteps(start, 65 + 131, map, allocator);
    const a3 = try takeSteps(start, 65 + (131 * 2), map, allocator);
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("check: {d}\n", .{og});
    try stdout.print("a1: {d}, a2: {d}, a3: {d}\n", .{a1, a2, a3});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn getContents(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 32 * 1024);
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

const Set = std.AutoArrayHashMap(Point, void);

const Point = struct {
    x: i32,
    y: i32,

    fn eql(a: Point, b: Point) bool {
        return a.x == b.x and a.y == b.y;
    }
};

fn takeSteps(start: Point, number: usize, map: []const []const u8, allocator: std.mem.Allocator) !usize {
    var list = try allocator.dupe(Point, &.{start});
    defer allocator.free(list);
    for (0..number) |_| {
        var set = Set.init(allocator);
        defer set.deinit();
        for (list) |pt| {
            const neighbors = getNeighbors(pt);
            for (neighbors) |neighbor| {
                const y: usize = @intCast(@mod(neighbor.y, @as(i32, @intCast(map.len))));
                const x: usize = @intCast(@mod(neighbor.x, @as(i13, @intCast(map[y].len))));
                if (map[y][x] != '#') try set.put(neighbor, {});
            }
        }
        allocator.free(list);
        list = try allocator.dupe(Point, set.keys());
    }
    return list.len;
}

fn getNeighbors(pt: Point) [4]Point {
    return .{
        .{ .x = pt.x - 1, .y = pt.y },
        .{ .x = pt.x + 1, .y = pt.y },
        .{ .x = pt.x, .y = pt.y - 1 },
        .{ .x = pt.x, .y = pt.y + 1 },
    };
}
