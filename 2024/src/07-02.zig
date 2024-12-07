const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("07.txt", .{});
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

fn process(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var count: u64 = 0;
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    var list: std.ArrayListUnmanaged(u64) = .{};
    defer list.deinit(allocator);
    while (iterator.next()) |line| {
        list.clearRetainingCapacity();
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.BadInput;
        const res = try std.fmt.parseInt(u64, line[0..colon], 10);
        var tokenizer = std.mem.tokenizeScalar(u8, line[colon + 1 ..], ' ');
        while (tokenizer.next()) |token|
            try list.append(allocator, try std.fmt.parseInt(u64, token, 10));
        if (matchTarget(res, list.items[0], list.items[1..]))
            count += res;
    }
    return count;
}

fn matchTarget(target: u64, subtotal: u64, remainder: []const u64) bool {
    if (remainder.len == 0) return target == subtotal;
    if (subtotal > target) return false;
    return matchTarget(target, subtotal * remainder[0], remainder[1..]) or
        matchTarget(target, concat(subtotal, remainder[0]), remainder[1..]) or
        matchTarget(target, subtotal + remainder[0], remainder[1..]);
}

fn concat(a: u64, b: u64) u64 {
    const digits = std.math.log10_int(b);
    return a * std.math.pow(u64, 10, digits + 1) + b;
}

test concat {
    try std.testing.expectEqual(1234, concat(12, 34));
}

test {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(11387, output);
}
