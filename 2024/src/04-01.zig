pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("04.txt", .{});
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
    var list: std.ArrayListUnmanaged([]const u8) = .{};
    defer list.deinit(allocator);
    const MAS = "MAS";
    const directions = std.meta.tags(Direction);

    var iter = std.mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |line| try list.append(allocator, line);
    const y_max = list.items.len - 1;
    var count: u32 = 0;
    for (list.items, 0..) |row, y| {
        const x_max = row.len - 1;
        var idx: usize = 0;
        while (std.mem.indexOfScalarPos(u8, row, idx, 'X')) |x| {
            idx = x + 1;
            for (directions) |where| {
                var i = x;
                var j = y;
                for (MAS) |letter| {
                    i, j = where.walk(i, j, x_max, y_max) catch break;
                    if (list.items[j][i] != letter) break;
                } else count += 1;
            }
        }
    }
    return count;
}

const Direction = enum {
    north,
    east,
    south,
    west,
    northeast,
    northwest,
    southeast,
    southwest,

    fn walk(where: Direction, x: usize, y: usize, x_max: usize, y_max: usize) error{Overflow}!struct { usize, usize } {
        return switch (where) {
            .north => if (y == 0) error.Overflow else .{ x, y - 1 },
            .east => if (x == x_max) error.Overflow else .{ x + 1, y },
            .south => if (y == y_max) error.Overflow else .{ x, y + 1 },
            .west => if (x == 0) error.Overflow else .{ x - 1, y },
            .northeast => if (x == x_max or y == 0) error.Overflow else .{ x + 1, y - 1 },
            .northwest => if (x == 0 or y == 0) error.Overflow else .{ x - 1, y - 1 },
            .southeast => if (x == x_max or y == y_max) error.Overflow else .{ x + 1, y + 1 },
            .southwest => if (x == 0 or y == y_max) error.Overflow else .{ x - 1, y + 1 },
        };
    }
};

test {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(18, output);
}

const std = @import("std");
