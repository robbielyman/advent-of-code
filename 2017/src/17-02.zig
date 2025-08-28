const std = @import("std");

pub fn process(_: std.mem.Allocator, input: []const u8) !usize {
    const token = std.mem.trimEnd(u8, input, &.{ 0, '\n' });
    const step_size = try std.fmt.parseInt(usize, token, 10);
    var idx: usize = 0;
    var ret: usize = 0;
    for (1..50_000_001) |i| {
        idx += step_size;
        idx %= i;
        if (idx == 0) ret = i;
        idx += 1;
    }
    return ret;
}
