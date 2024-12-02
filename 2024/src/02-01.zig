const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("02.txt", .{});
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

fn process(allocator: std.mem.Allocator, input: []const u8) !u32 {
    var list: std.ArrayListUnmanaged(u32) = .{};
    defer list.deinit(allocator);

    var count: u32 = 0;

    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        defer list.clearRetainingCapacity();
        var chunks = std.mem.tokenizeScalar(u8, line, ' ');
        while (chunks.next()) |chunk|
            try list.append(allocator, try std.fmt.parseInt(u32, chunk, 10));
        switch (std.math.order(list.items[0], list.items[1])) {
            .eq => continue,
            .lt => { // increasing
                for (list.items[0 .. list.items.len - 1], list.items[1..]) |a, b| {
                    if (a >= b or b - a > 3) break;
                } else count += 1;
            },
            .gt => { // decreasing
                for (list.items[0 .. list.items.len - 1], list.items[1..]) |a, b| {
                    if (b >= a or a - b > 3) break;
                } else count += 1;
            },
        }
    }
    return count;
}

test {
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;

    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(2, output);
}
