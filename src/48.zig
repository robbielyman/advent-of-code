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

    const vec = solveForPosition(hailstones);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    inline for (0..3) |i| try stdout.print("{d}\n", .{vec[i]});
    try stdout.print("{d}\n", .{
        @as(i64, @intFromFloat(vec[0] + vec[1] + vec[2])),
    });
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
    std.testing.log_level = .info;
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
    const got = solveForPosition(list.items);
    const expected: [3]f64 = .{ 24, 13, 10 };
    for (expected, got) |e, g| {
        try std.testing.expectApproxEqAbs(e, g, 0.001);
    }
}

const Hailstone = struct {
    position: [3]f64,
    heading: [3]f64,
};

fn solve(
    comptime m: usize,
    comptime n: comptime_int,
    matrix: *[m]@Vector(n, f64),
) void {
    var h: usize = 0;
    var k: usize = 0;
    while (h < m and k < n) {
        std.log.info("", .{});
        inline for (0..m) |i| {
            std.log.info("{any}", .{matrix[i]});
        }
        const slice: [m]f64 = slice: {
            var s: [m]f64 = undefined;
            inline for (0..m) |i| {
                s[i] = if (matrix[i][k] == 0) std.math.floatMax(f64) else @abs(matrix[i][k]);
            }
            break :slice s;
        };
        const i_max = std.mem.indexOfMin(f64, slice[h..]);
        if (matrix[h + i_max][k] == 0) {
            k += 1;
            continue;
        }
        const swap = matrix[h + i_max];
        matrix[h + i_max] = matrix[h];
        matrix[h] = swap;
        matrix[h] /= @splat(matrix[h][k]);

        for (0..m) |i| {
            if (matrix[i][k] == 0 or i == h) continue;

            const f: f64 = matrix[i][k];

            matrix[i] -= @as(@Vector(n, f64), @splat(f)) * matrix[h];
        }
        h += 1;
        k += 1;
    }
}

test "solve" {
    std.testing.log_level = .info;
    var matrix: [3]@Vector(4, f64) = .{
        .{ 2, 1, -1, 8 },
        .{ -3, -1, 2, -11 },
        .{ -2, 1, 2, -3 },
    };
    solve(3, 4, &matrix);
    const expected: [3]@Vector(4, f64) = .{
        .{ 1, 0, 0, 2 },
        .{ 0, 1, 0, 3 },
        .{ 0, 0, 1, -1 },
    };
    for (expected, matrix) |e, g| {
        inline for (0..4) |i| {
            try std.testing.expectApproxEqAbs(e[i], g[i], 0.001);
        }
    }
}

fn parseLine(line: []const u8) !Hailstone {
    const idx = std.mem.indexOfScalar(u8, line, '@') orelse return error.ParseFailed;
    const position = position: {
        var tokenizer = std.mem.tokenizeAny(u8, line[0..idx], ", ");
        var ret: [3]f64 = undefined;
        inline for (0..3) |i| {
            const next = tokenizer.next() orelse return error.ParseFailed;
            ret[i] = try std.fmt.parseFloat(f64, next);
        }
        break :position ret;
    };
    const heading = heading: {
        var tokenizer = std.mem.tokenizeAny(u8, line[idx + 1 ..], ", ");
        var ret: [3]f64 = undefined;
        inline for (0..3) |i| {
            const next = tokenizer.next() orelse return error.ParseFailed;
            ret[i] = try std.fmt.parseFloat(f64, next);
        }
        break :heading ret;
    };
    return .{
        .position = .{
            position[0],
            position[1],
            position[2],
        },
        .heading = .{
            heading[0],
            heading[1],
            heading[2],
        },
    };
}

fn solveForPosition(hailstones: []const Hailstone) [3]f64 {
    const h1 = hailstones[0].position;
    const v1 = hailstones[0].heading;
    const h2 = hailstones[1].position;
    const v2 = hailstones[1].heading;
    const h3 = hailstones[2].position;
    const v3 = hailstones[2].heading;
    const col1 = crossProduct(f64, v2, h2) - crossProduct(f64, v1, h1);
    const col2 = crossProduct(f64, v3, h3) - crossProduct(f64, v1, h1);
    var matrix: [6]@Vector(7, f64) = .{
        .{
            0, h1[2] - h2[2], h2[1] - h1[1], 0, v1[2] - v2[2], v2[1] - v1[1], col1[0],
        },
        .{
            h2[2] - h1[2], 0, h1[0] - h2[0], v2[2] - v1[2], 0, v1[0] - v2[0], col1[1],
        },
        .{
            h1[1] - h2[1], h2[0] - h1[0], 0, v1[1] - v2[1], v2[0] - v1[0], 0, col1[2],
        },
        .{
            0, h1[2] - h3[2], h3[1] - h1[1], 0, v1[2] - v3[2], v3[1] - v1[1], col2[0],
        },
        .{
            h3[2] - h1[2], 0, h1[0] - h3[0], v3[2] - v1[2], 0, v1[0] - v3[0], col2[1],
        },
        .{
            h1[1] - h3[1], h3[0] - h1[0], 0, v1[1] - v3[1], v3[0] - v1[0], 0, col2[2],
        },
    };
    solve(6, 7, &matrix);

    std.log.info("first solve done!", .{});

    for (0..6) |i| {
        matrix[5 - i] /= @splat(matrix[5 - i][5 - i]);
        solve(6, 7, &matrix);
    }
    std.log.err("{any}", .{matrix});
    return .{ matrix[3][6], matrix[4][6], matrix[5][6] };
}

fn crossProduct(
    comptime T: type,
    a: @Vector(3, T),
    b: @Vector(3, T),
) @Vector(3, T) {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}
