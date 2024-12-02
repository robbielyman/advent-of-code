const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("02.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const reader = br.reader();
    const input = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer = try std.time.Timer.start();
    const output = try process(input);

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{timer.read() / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) !i32 {
    var horiz: i32 = 0;
    var vert: i32 = 0;
    var iter = std.mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |line| {
        const idx = std.mem.indexOfScalar(u8, line, ' ') orelse return error.BadInput;
        const direction = line[0..idx];
        const change = try std.fmt.parseInt(i32, line[idx + 1 ..], 10);
        if (std.mem.eql(u8, "forward", direction)) {
            horiz += change;
        } else if (std.mem.eql(u8, "up", direction)) {
            vert -= change;
        } else if (std.mem.eql(u8, "down", direction)) {
            vert += change;
        } else return error.BadInput;
    }
    return horiz * vert;
}

test process {
    const input =
        \\forward 5
        \\down 5
        \\forward 8
        \\up 3
        \\down 8
        \\forward 2
    ;
    const output = try process(input);
    try std.testing.expectEqual(150, output);
}
