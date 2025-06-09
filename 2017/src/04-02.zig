const std = @import("std");

const Set = std.StringArrayHashMapUnmanaged(void);

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
    var set: Set = .empty;
    defer set.deinit(allocator);
    defer for (set.keys()) |key| allocator.free(key);

    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var valid: usize = 0;
    while (lines.next()) |line| {
        for (set.keys()) |key| allocator.free(key);
        set.clearRetainingCapacity();
        if (try validate(allocator, &set, line)) valid += 1;
    }
    return valid;
}

fn validate(allocator: std.mem.Allocator, set: *Set, line: []const u8) !bool {
    var it = std.mem.tokenizeScalar(u8, line, ' ');
    while (it.next()) |token| {
        const copy = try allocator.dupe(u8, token);
        std.mem.sort(u8, copy, {}, struct {
            fn lessThan(_: void, a: u8, b: u8) bool {
                return a < b;
            }
        }.lessThan);
        const res = try set.getOrPut(allocator, copy);
        if (res.found_existing) {
            allocator.free(copy);
            return false;
        }
        res.key_ptr.* = copy;
    }
    return true;
}

test validate {
    const allocator = std.testing.allocator;
    var set: Set = .empty;
    defer set.deinit(allocator);
    defer for (set.keys()) |key| allocator.free(key);
    const inputs: []const []const u8 = &.{
        "abcde fghij",
        "abcde xyz ecdab",
        "a ab abc abd abf abj",
        "iiii oiii ooii oooi oooo",
        "oiii ioii iioi iiio",
    };
    const expectations: []const bool = &.{ true, false, true, true, false };
    for (inputs, expectations) |input, expected| {
        for (set.keys()) |key| allocator.free(key);
        set.clearRetainingCapacity();
        try std.testing.expectEqual(expected, try validate(allocator, &set, input));
    }
}
