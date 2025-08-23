const std = @import("std");

pub fn process(_: std.mem.Allocator, input: []const u8) !u32 {
    var count: u32 = 0;
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    const line_one = it.next().?;
    const line_two = it.next().?;
    var a: Generator = .{
        .factor = 16807,
        .prev = try std.fmt.parseInt(u32, line_one[std.mem.lastIndexOfScalar(u8, line_one, ' ').? + 1 ..], 10),
    };
    var b: Generator = .{
        .factor = 48271,
        .prev = try std.fmt.parseInt(u32, line_two[std.mem.lastIndexOfScalar(u8, line_two, ' ').? + 1 ..], 10),
    };
    for (0..40_000_000) |_| {
        const one = a.step() & std.math.maxInt(u16);
        const two = b.step() & std.math.maxInt(u16);
        if (one == two) count += 1;
    }
    return count;
}

const Generator = struct {
    factor: u32,
    prev: u32,

    fn step(self: *Generator) u32 {
        const next: u64 = @as(u64, self.prev) * self.factor;
        self.prev = @intCast(next % 2147483647);
        return self.prev;
    }
};

test process {
    const input =
        \\ 65
        \\ 8921
    ;
    const count = try process(undefined, input);
    try std.testing.expectEqual(588, count);
}
