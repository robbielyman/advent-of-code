const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("01.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const reader = br.reader();
    const input = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer = try std.time.Timer.start();
    const output = try process(input);

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{timer.read() / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) !usize {
    var last: i32 = 0;
    var iter = std.mem.tokenizeScalar(u8, input, '\n');
    var count: usize = 0;
    while (iter.next()) |line| {
        const num = try std.fmt.parseInt(i32, line, 10);
        defer last = num;
        if (last > 0 and num > last) count += 1;
    }
    return count;
}

test process {
    const input =
        \\199
        \\200
        \\208
        \\210
        \\200
        \\207
        \\240
        \\269
        \\260
        \\263
    ;
    const output = try process(input);
    try std.testing.expectEqual(7, output);
}
