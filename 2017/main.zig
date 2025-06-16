const solution = @import("solution");
const std = @import("std");

pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    const arg = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, arg);

    const file = try std.fs.cwd().openFile(arg[1], .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var timer: std.time.Timer = try .start();
    const output = try solution.process(allocator, input);
    const elapsed = timer.lap();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}
