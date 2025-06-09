const std = @import("std");

pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    const file = try std.fs.cwd().openFile("04.txt", .{});
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer: std.time.Timer = try .start();
    const output = try process(allocator, input);
    const elapsed = timer.lap();

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var set: std.StringHashMapUnmanaged(void) = .empty;
    defer set.deinit(allocator);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var valid: usize = 0;
    while (lines.next()) |line| {
        set.clearRetainingCapacity();
        if (try validate(allocator, &set, line)) valid += 1;
    }
    return valid;
}

fn validate(allocator: std.mem.Allocator, set: *std.StringHashMapUnmanaged(void), line: []const u8) !bool {
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    while (it.next()) |token| {
        const res = try set.getOrPut(allocator, token);
        if (res.found_existing) return false;
        res.key_ptr.* = token;
    }
    return true;
}

test validate {
    const allocator = std.testing.allocator;
    var set: std.StringHashMapUnmanaged(void) = .empty;
    defer set.deinit(allocator);
    const inputs: []const []const u8 = &.{
        "aa bb cc dd ee",
        "aa bb cc dd aa",
        "aa bb cc dd aaa",
    };
    const expectations: []const bool = &.{ true, false, true };
    for (inputs, expectations) |input, expected| {
        set.clearRetainingCapacity();
        try std.testing.expectEqual(expected, try validate(allocator, &set, input));
    }
}
