const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("13.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn solve2x3(i_matrix: [2][3]i64) error{NoIntegerSolutions}![2]i64 {
    const V = @Vector(3, i64);
    var matrix: [2]V = undefined;
    for (&i_matrix, 0..) |row, i| matrix[i] = row;
    // clear the first column
    while (matrix[0][0] != 0 and matrix[1][0] != 0) {
        const a: i64 = @intCast(@abs(matrix[0][0]));
        const b: i64 = @intCast(@abs(matrix[1][0]));
        const sign = (matrix[0][0] >= 0 and matrix[1][0] >= 0) or (matrix[0][0] <= 0 and matrix[1][0] <= 0);
        var mult: i64 = 1;
        if (a > b) {
            while (b * mult < a) mult += 1;
            if (sign) mult = -mult;
            matrix[0] += matrix[1] * @as(V, @splat(mult));
        } else {
            while (a * mult < b) mult += 1;
            if (sign) mult = -mult;
            matrix[1] += matrix[0] * @as(V, @splat(mult));
        }
    }
    if (matrix[1][0] == 0) {
        if (@mod(matrix[1][2], matrix[1][1]) != 0) return error.NoIntegerSolutions;
        matrix[1] /= @splat(matrix[1][1]);
        matrix[0] -= matrix[1] * @as(V, @splat(matrix[0][1]));
        if (@mod(matrix[0][2], matrix[0][0]) != 0) return error.NoIntegerSolutions;
        matrix[0] /= @splat(matrix[0][0]);
        return .{ matrix[0][2], matrix[1][2] };
    } else {
        if (@mod(matrix[0][2], matrix[0][1]) != 0) return error.NoIntegerSolutions;
        matrix[0] /= @splat(matrix[0][1]);
        matrix[1] -= matrix[0] * @as(V, @splat(matrix[1][1]));
        if (@mod(matrix[1][2], matrix[1][0]) != 0) return error.NoIntegerSolutions;
        matrix[1] /= @splat(matrix[1][0]);
        return .{ matrix[1][2], matrix[0][2] };
    }
}

test solve2x3 {
    const x, const y = try solve2x3(.{ .{ 94, 22, 8400 }, .{ 34, 67, 5400 } });
    try std.testing.expectEqualSlices(i64, &.{ 80, 40 }, &.{ x, y });
    try std.testing.expectError(error.NoIntegerSolutions, solve2x3(.{ .{ 94, 34, 8400 }, .{ 22, 67, 5400 } }));
}

fn process(input: []const u8) !i64 {
    var tokens_count: i64 = 0;
    var machine_iter = std.mem.tokenizeSequence(u8, input, "\n\n");
    while (machine_iter.next()) |machine| {
        var lines = std.mem.tokenizeScalar(u8, machine, '\n');
        const a_x, const a_y = try parse(lines.next() orelse return error.BadInput);
        const b_x, const b_y = try parse(lines.next() orelse return error.BadInput);
        const p_x, const p_y = try parse(lines.next() orelse return error.BadInput);
        const a_presses, const b_presses = solve2x3(.{ .{ a_x, b_x, 10000000000000 + p_x }, .{ a_y, b_y, 10000000000000 + p_y } }) catch continue;
        tokens_count += 3 * a_presses + b_presses;
    }
    return tokens_count;
}

fn parse(line: []const u8) !struct { i64, i64 } {
    if (std.mem.startsWith(u8, line, "Button ")) {
        const plus = "Button A: X+".len;
        const comma = std.mem.indexOfScalarPos(u8, line, plus, ',') orelse return error.ParseFailed;
        const x = try std.fmt.parseInt(i64, line[plus..comma], 10);
        const plus_again = std.mem.indexOfScalarPos(u8, line, comma, '+') orelse return error.ParseFailed;
        const y = try std.fmt.parseInt(i64, line[plus_again + 1 ..], 10);
        return .{ x, y };
    }
    const equals = std.mem.indexOfScalar(u8, line, '=') orelse return error.ParseFailed;
    const comma = std.mem.indexOfScalarPos(u8, line, equals, ',') orelse return error.ParseFailed;
    const x = try std.fmt.parseInt(i64, line[equals + 1 .. comma], 10);
    const equals_again = std.mem.indexOfScalarPos(u8, line, comma, '=') orelse return error.ParseFailed;
    const y = try std.fmt.parseInt(i64, line[equals_again + 1 ..], 10);
    return .{ x, y };
}

test {
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;

    const output = try process(input);
    try std.testing.expectEqual(875318608908, output);
}
