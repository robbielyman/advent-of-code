const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("25.txt", .{});
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

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var locks: std.ArrayListUnmanaged([5]u8) = .{};
    defer locks.deinit(allocator);

    var keys: std.ArrayListUnmanaged([5]u8) = .{};
    defer keys.deinit(allocator);

    var iter = std.mem.tokenizeSequence(u8, input, "\n\n");
    while (iter.next()) |thing| {
        var unpacked: [7][]const u8 = unpack: {
            var unpacked: [7][]const u8 = undefined;
            var inner_iter = std.mem.tokenizeScalar(u8, thing, '\n');
            for (&unpacked) |*ptr|
                ptr.* = inner_iter.next() orelse return error.BadInput;
            break :unpack unpacked;
        };
        var key = true;
        if (std.mem.indexOfScalar(u8, unpacked[0], '.') != null) {
            key = false;
            std.mem.reverse([]const u8, &unpacked);
        }
        var levels: [5]u8 = .{ 0, 0, 0, 0, 0 };
        for (&levels, 0..) |*ptr, i| {
            while (ptr.* < 7 and unpacked[ptr.* + 1][i] == '#') ptr.* += 1;
        }
        if (key)
            try keys.append(allocator, levels)
        else
            try locks.append(allocator, levels);
    }

    var counter: usize = 0;
    for (keys.items) |key| {
        for (locks.items) |lock| {
            for (&key, &lock) |i, j| {
                if (i + j > 5) break;
            } else counter += 1;
        }
    }
    return counter;
}

test {
    const input =
        \\#####
        \\.####
        \\.####
        \\.####
        \\.#.#.
        \\.#...
        \\.....
        \\
        \\#####
        \\##.##
        \\.#.##
        \\...##
        \\...#.
        \\...#.
        \\.....
        \\
        \\.....
        \\#....
        \\#....
        \\#...#
        \\#.#.#
        \\#.###
        \\#####
        \\
        \\.....
        \\.....
        \\#.#..
        \\###..
        \\###.#
        \\###.#
        \\#####
        \\
        \\.....
        \\.....
        \\.....
        \\#....
        \\#.#..
        \\#.#.#
        \\#####
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(3, output);
}
