const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("01.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var timer = try std.time.Timer.start();
    const output = try process(allocator, input);
    const elapsed = timer.read() / std.time.ns_per_us;

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !i32 {
    var left: std.ArrayListUnmanaged(i32) = .{};
    var right: std.ArrayListUnmanaged(i32) = .{};
    defer left.deinit(allocator);
    defer right.deinit(allocator);

    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        const delimiter = "   ";
        const idx = std.mem.indexOf(u8, line, delimiter) orelse return error.BadInput;
        const left_in = try std.fmt.parseInt(i32, line[0..idx], 10);
        const right_in = try std.fmt.parseInt(i32, line[idx + delimiter.len ..], 10);
        try left.append(allocator, left_in);
        try right.append(allocator, right_in);
    }

    std.mem.sort(i32, left.items, {}, lessThan);
    std.mem.sort(i32, right.items, {}, lessThan);

    var output: i32 = 0;
    for (left.items, right.items) |l, r| {
        output += @intCast(@abs(l - r));
    }
    return output;
}

fn lessThan(_: void, a: i32, b: i32) bool {
    return a < b;
}

test {
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(11, output);
}
