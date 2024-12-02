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
    var orders: std.ArrayListUnmanaged(std.math.Order) = .{};
    var safety: std.ArrayListUnmanaged(bool) = .{};
    defer list.deinit(allocator);
    defer safety.deinit(allocator);
    defer orders.deinit(allocator);

    var count: u32 = 0;

    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        defer {
            list.clearRetainingCapacity();
            orders.clearRetainingCapacity();
            safety.clearRetainingCapacity();
        }
        var chunks = std.mem.tokenizeScalar(u8, line, ' ');
        while (chunks.next()) |chunk|
            try list.append(allocator, try std.fmt.parseInt(u32, chunk, 10));
        try safety.ensureUnusedCapacity(allocator, list.items.len - 1);
        try orders.ensureUnusedCapacity(allocator, list.items.len - 1);
        safety.items.len = list.items.len - 1;
        orders.items.len = list.items.len - 1;
        if (testSafety(list.items, orders.items, safety.items)) {
            count += 1;
            continue;
        }
        const sublist = try allocator.alloc(u32, list.items.len - 1);
        defer allocator.free(sublist);
        safety.items.len -= 1;
        orders.items.len -= 1;
        for (0..list.items.len) |i| {
            @memcpy(sublist[0..i], list.items[0..i]);
            @memcpy(sublist[i..], list.items[i + 1 ..]);
            if (testSafety(sublist, orders.items, safety.items)) {
                count += 1;
                break;
            }
        }
    }
    return count;
}

fn testSafety(list: []const u32, in_orders: []std.math.Order, in_safety: []bool) bool {
    for (list[0 .. list.len - 1], list[1..], in_safety, in_orders) |a, b, *safe, *order| {
        order.* = std.math.order(a, b);
        safe.* = switch (order.*) {
            .eq => false,
            .lt => b - a <= 3,
            .gt => a - b <= 3,
        };
    }
    const all_safe = std.mem.allEqual(bool, in_safety, true);
    if (!all_safe) return false;
    return std.mem.allEqual(std.math.Order, in_orders, .lt) or std.mem.allEqual(std.math.Order, in_orders, .gt);
}

const Safety = struct {
    which: std.math.Order,
    safe: bool,
};

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
    try std.testing.expectEqual(4, output);
}
