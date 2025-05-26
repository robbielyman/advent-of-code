pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    const file = try std.fs.cwd().openFile("02.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer: std.time.Timer = try .start();
    const output = try process(input);
    const elapsed = timer.lap();

    try stdout.print("{}\n", .{output});
    try stdout.print("{}us elapsed\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) !u32 {
    var ret: u32 = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var largest: u32 = 0;
        var smallest: u32 = std.math.maxInt(u32);
        var it = std.mem.tokenizeAny(u8, line, " \t");
        while (it.next()) |token| {
            const number = try std.fmt.parseInt(u32, token, 10);
            largest = @max(largest, number);
            smallest = @min(smallest, number);
        }
        ret += largest - smallest;
    }
    return ret;
}

test {
    const input =
        \\5 1 9 5
        \\7 5 3
        \\2 4 6 8
    ;
    const output = try process(input);
    try std.testing.expectEqual(18, output);
}

const std = @import("std");
