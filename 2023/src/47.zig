const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const hailstones = hailstones: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :hailstones try getHailstones(filename, allocator);
    };
    defer allocator.free(hailstones);

    var count: usize = 0;
    for (hailstones, 0..) |a, i| {
        for (hailstones[i + 1 ..]) |b| {
            if (a.intersectionTimes(b)) |times| {
                if (times[0] >= 0 and times[1] >= 0) {
                    const x = @as(f64, @floatFromInt(a.position.x)) + @as(f64, @floatFromInt(a.heading.dx)) * times[0];
                    const y = @as(f64, @floatFromInt(a.position.y)) + @as(f64, @floatFromInt(a.heading.dy)) * times[0];
                    if ((x >= 200000000000000 and x <= 400000000000000) and
                        (y >= 200000000000000 and y <= 400000000000000)) count += 1;
                }
            }
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{
        @divTrunc(timer.read(), std.time.ns_per_ms),
    });
    try bw.flush();
}

fn getHailstones(filename: []const u8, allocator: std.mem.Allocator) ![]const Hailstone {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    const reader = file.reader();
    var list = std.ArrayList(Hailstone).init(allocator);
    errdefer list.deinit();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    var done = false;

    while (!done) {
        defer buffer.clearRetainingCapacity();
        reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) done = true else return err;
        };
        if (buffer.items.len > 0) {
            const hailstone = try parseLine(buffer.items);
            try list.append(hailstone);
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

test "parseInput" {
    const input =
        \\19, 13, 30 @ -2,  1, -2
        \\18, 19, 22 @ -1, -1, -2
        \\20, 25, 34 @ -2, -2, -4
        \\12, 31, 28 @ -1, -2, -1
        \\20, 19, 15 @  1, -5, -3
    ;
    const allocator = std.testing.allocator;
    var list = std.ArrayList(Hailstone).init(allocator);
    defer list.deinit();
    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (tokenizer.next()) |line| {
        const hailstone = try parseLine(line);
        try list.append(hailstone);
    }
    var count: usize = 0;
    for (list.items, 0..) |a, i| {
        for (list.items[i + 1 ..]) |b| {
            if (a.intersectionTimes(b)) |times| {
                if (times[0] > 0 and times[1] > 0) {
                    const x = a.position.x + times[0] * a.heading.dx;
                    const y = a.position.y + times[0] * a.heading.dy;
                    if (x >= 7 and x <= 27 and y >= 7 and y <= 27) count += 1;
                }
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 2), count);
}

const Hailstone = struct {
    position: struct {
        x: i64,
        y: i64,
        z: i64,
    },
    heading: struct {
        dx: i64,
        dy: i64,
        dz: i64,
    },

    fn intersectionTimes(a: Hailstone, b: Hailstone) ?[2]f64 {
        // RREF
        std.debug.assert(a.heading.dx != 0);
        var row1: @Vector(3, f64) = .{
            @floatFromInt(a.heading.dx),
            @floatFromInt(-b.heading.dx),
            @floatFromInt(b.position.x - a.position.x),
        };
        var row2: @Vector(3, f64) = .{
            @floatFromInt(a.heading.dy),
            @floatFromInt(-b.heading.dy),
            @floatFromInt(b.position.y - a.position.y),
        };
        row1 /= @splat(row1[0]);
        row2 -= @as(@Vector(3, f64), @splat(row2[0])) * row1;
        if (row2[1] == 0) return null;
        row2 /= @splat(row2[1]);
        row1 -= @as(@Vector(3, f64), @splat(row1[1])) * row2;
        return .{ row1[2], row2[2] };
    }
};

fn parseLine(line: []const u8) !Hailstone {
    const idx = std.mem.indexOfScalar(u8, line, '@') orelse return error.ParseFailed;
    const position = position: {
        var tokenizer = std.mem.tokenizeAny(u8, line[0..idx], ", ");
        var ret: [3]i64 = undefined;
        inline for (0..3) |i| {
            const next = tokenizer.next() orelse return error.ParseFailed;
            ret[i] = try std.fmt.parseInt(i64, next, 10);
        }
        break :position ret;
    };
    const heading = heading: {
        var tokenizer = std.mem.tokenizeAny(u8, line[idx + 1 ..], ", ");
        var ret: [3]i64 = undefined;
        inline for (0..3) |i| {
            const next = tokenizer.next() orelse return error.ParseFailed;
            ret[i] = try std.fmt.parseInt(i64, next, 10);
        }
        break :heading ret;
    };
    return .{
        .position = .{
            .x = position[0],
            .y = position[1],
            .z = position[2],
        },
        .heading = .{
            .dx = heading[0],
            .dy = heading[1],
            .dz = heading[2],
        },
    };
}
