const std = @import("std");

pub fn process(_: std.mem.Allocator, input: []const u8) !u32 {
    var delay: u32 = 0;
    delay: while (true) : (delay += 1) {
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        while (it.next()) |line| {
            errdefer std.log.err("line: {s}", .{line});
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.BadInput;
            const depth = try std.fmt.parseInt(u32, line[0..colon], 10);
            const range = try std.fmt.parseInt(u32, line[colon + 2 ..], 10);
            if (scannerPosition(range, depth + delay) == 0) continue :delay;
        } else break :delay;
    }
    return delay;
}

fn scannerPosition(range: u32, time: u32) u32 {
    if (range < 2) return 1;
    const period = range * 2 - 2;
    const pos = time % period;
    return if (pos < range) pos else range - ((pos % (range - 1)) + 1);
}

test scannerPosition {
    const positions: []const u32 = &.{ 0, 1, 2, 3, 4, 3, 2, 1, 0, 1 };
    for (positions, 0..) |expected, time| {
        const got = scannerPosition(5, @intCast(time));
        errdefer std.log.err("exp: {d}", .{expected});
        errdefer std.log.err("got: {d}", .{got});
        try std.testing.expectEqual(expected, got);
    }
}

test process {
    const input =
        \\0: 3
        \\1: 2
        \\4: 4
        \\6: 4
    ;
    try std.testing.expectEqual(10, process(std.testing.allocator, input));
}
