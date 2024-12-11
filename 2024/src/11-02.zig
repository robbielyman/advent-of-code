const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("11.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input, 75);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

const Key = struct {
    stone: u64,
    iterations: usize,
};

fn process(allocator: std.mem.Allocator, input: []const u8, iterations: usize) !usize {
    var cache: std.AutoHashMapUnmanaged(Key, usize) = .{};
    defer cache.deinit(allocator);

    var iter = std.mem.tokenizeAny(u8, input, " \n");
    var count: usize = 0;
    while (iter.next()) |token| {
        const number = try std.fmt.parseInt(u64, token, 10);
        try computeNumberOfChildren(allocator, &cache, number, iterations);
        count += cache.get(.{ .stone = number, .iterations = iterations }).?;
    }
    return count;
}

fn computeNumberOfChildren(allocator: std.mem.Allocator, cache: *std.AutoHashMapUnmanaged(Key, usize), stone: u64, iterations: usize) !void {
    const key: Key = .{
        .stone = stone,
        .iterations = iterations,
    };
    if (cache.get(key)) |_| return;
    // if we're done, we're done
    if (iterations == 0) {
        try cache.put(allocator, key, 1);
        return;
    }
    // recurse
    const a, const b = try Child.childrenFromParent(stone);
    if (a == .none) return error.None;
    try computeNumberOfChildren(allocator, cache, @intFromEnum(a), iterations - 1);
    switch (b) {
        .none => {
            const val = cache.get(.{ .stone = @intFromEnum(a), .iterations = iterations - 1 }).?;
            try cache.put(allocator, key, val);
        },
        else => {
            try computeNumberOfChildren(allocator, cache, @intFromEnum(b), iterations - 1);
            const a_val = cache.get(.{ .stone = @intFromEnum(a), .iterations = iterations - 1 }).?;
            const b_val = cache.get(.{ .stone = @intFromEnum(b), .iterations = iterations - 1 }).?;
            try cache.put(allocator, key, a_val + b_val);
        },
    }
}

const Child = enum(u64) {
    none = std.math.maxInt(u64),
    _,

    fn from(number: u64) !Child {
        if (number == std.math.maxInt(u64)) return error.TooBig;
        return @enumFromInt(number);
    }

    fn childrenFromParent(parent: u64) ![2]Child {
        if (parent == 0) return .{ try from(1), .none };
        var buf: [24]u8 = undefined;
        const slice = std.fmt.bufPrint(&buf, "{d}", .{parent}) catch unreachable;
        if (slice.len % 2 == 0) {
            const a = std.fmt.parseInt(u64, slice[0 .. slice.len / 2], 10) catch unreachable;
            const b = std.fmt.parseInt(u64, slice[slice.len / 2 ..], 10) catch unreachable;
            return .{ try from(a), try from(b) };
        }
        return .{ try from(parent * 2024), .none };
    }
};

test {
    const input = "125 17";
    const output = try process(std.testing.allocator, input, 25);
    try std.testing.expectEqual(55312, output);
}
