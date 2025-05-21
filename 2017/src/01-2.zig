const std = @import("std");

pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) return error.MissingFilename;
    const file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer: std.time.Timer = try .start();
    const output = try process(input);
    const elapsed = timer.lap();

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) !usize {
    var count: usize = 0;
    const offset = input.len / 2;
    for (input, 0..) |byte, i| {
        const next = input[(i + offset) % input.len];
        if (byte != next) continue;
        count += (byte - '0');
    }
    return count;
}

test process {
    const cases: []const []const u8 = &.{
        "1212",
        "1221",
        "123425",
        "123123",
        "12131415",
    };
    const results: []const usize = &.{ 6, 0, 4, 12, 4 };

    for (cases, results) |input, expected| {
        try std.testing.expectEqual(expected, try process(input));
    }
}
