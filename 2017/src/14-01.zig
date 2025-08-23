const std = @import("std");
const knotHash = @import("10-02.zig").process;

pub fn process(_: std.mem.Allocator, raw_in: []const u8) !u32 {
    var it = std.mem.tokenizeAny(u8, raw_in, &.{ '\n', '\t', 0 });
    const input = it.next().?;
    var count: u32 = 0;
    for (0..128) |i| {
        var buf: [16]u8 = @splat(0);
        var w: std.io.Writer = .{
            .buffer = &buf,
            .vtable = &.{
                .drain = std.io.Writer.failingDrain,
                .rebase = std.io.Writer.failingRebase,
            },
        };
        try w.print("{s}-{d}", .{ input, i });
        const hash = try knotHash(undefined, w.buffer[0..w.end]);
        const hex = try std.fmt.parseInt(u128, &hash, 16);
        std.log.info("{b:0>128}", .{hex});
        count += @popCount(hex);
    }
    return count;
}

test process {
    std.testing.log_level = .info;
    const input = "flqrgnkx";
    const output = try process(undefined, input);
    try std.testing.expectEqual(8108, output);
}
