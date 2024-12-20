const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("19.txt", .{});
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
    const split = std.mem.indexOf(u8, input, "\n\n") orelse return error.BadInput;
    var list: std.ArrayListUnmanaged([]const u8) = .{};
    defer list.deinit(allocator);
    {
        var tokenizer = std.mem.tokenizeSequence(u8, input[0..split], ", ");
        while (tokenizer.next()) |token| try list.append(allocator, token);
    }
    var ret: u32 = 0;
    var possible: std.StringHashMapUnmanaged(bool) = .{};
    defer possible.deinit(allocator);
    var iterator = std.mem.tokenizeScalar(u8, input[split + 2 ..], '\n');
    while (iterator.next()) |line| {
        try compute(allocator, line, &possible, list.items);
        if (possible.get(line).?) ret += 1;
    }
    return ret;
}

fn compute(
    allocator: std.mem.Allocator,
    line: []const u8,
    map: *std.StringHashMapUnmanaged(bool),
    prefixes: []const []const u8,
) !void {
    if (map.contains(line)) return;
    if (line.len == 0) {
        try map.put(allocator, line, true);
        return;
    }
    for (prefixes) |prefix| {
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        try compute(allocator, line[prefix.len..], map, prefixes);
        if (!map.get(line[prefix.len..]).?) continue;
        try map.put(allocator, line, true);
        return;
    }
    try map.put(allocator, line, false);
}

test {
    const input =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(6, output);
}
