const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("14.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(input, 101, 103);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8, width: i32, height: i32) !usize {
    const mid_x = @divExact(width - 1, 2);
    const mid_y = @divExact(height - 1, 2);
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    var quadrants: [4]usize = .{ 0, 0, 0, 0 };
    while (iterator.next()) |line| {
        const data = try parse(line);
        const x = @mod(data.position[0] + data.velocity[0] * 100, width);
        const y = @mod(data.position[1] + data.velocity[1] * 100, height);
        if (x < mid_x) {
            if (y < mid_y) quadrants[0] += 1;
            if (y > mid_y) quadrants[2] += 1;
        }
        if (x > mid_x) {
            if (y < mid_y) quadrants[1] += 1;
            if (y > mid_y) quadrants[3] += 1;
        }
    }
    return quadrants[0] * quadrants[1] * quadrants[2] * quadrants[3];
}

const Data = struct {
    position: struct { i32, i32 },
    velocity: struct { i32, i32 },
};

fn parse(line: []const u8) !Data {
    const comma = std.mem.indexOfScalar(u8, line, ',') orelse return error.ParseFailed;
    const p_x = try std.fmt.parseInt(i32, line[2..comma], 10);
    const space = std.mem.indexOfScalar(u8, line, ' ') orelse return error.ParseFailed;
    const p_y = try std.fmt.parseInt(i32, line[comma + 1 .. space], 10);
    const comma_2 = std.mem.indexOfScalarPos(u8, line, space, ',') orelse return error.ParseFailed;
    const v_x = try std.fmt.parseInt(i32, line[space + 3 .. comma_2], 10);
    const v_y = try std.fmt.parseInt(i32, line[comma_2 + 1 ..], 10);
    return .{
        .position = .{ p_x, p_y },
        .velocity = .{ v_x, v_y },
    };
}

test {
    const input =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
        \\p=2,0 v=2,-1
        \\p=0,0 v=1,3
        \\p=3,0 v=-2,-2
        \\p=7,6 v=-1,-3
        \\p=3,0 v=-1,-2
        \\p=9,3 v=2,3
        \\p=7,3 v=-1,2
        \\p=2,4 v=2,-3
        \\p=9,5 v=-3,-3
    ;

    const output = try process(input, 11, 7);
    try std.testing.expectEqual(12, output);
}
