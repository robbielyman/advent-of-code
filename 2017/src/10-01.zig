const std = @import("std");

pub fn process(_: std.mem.Allocator, input: []const u8) !u32 {
    var buf: [256]u8 = undefined;
    for (&buf, 0..) |*ptr, i| ptr.* = @intCast(i);
    var hsh: KnotHash = .{ .buf = &buf };
    var it = std.mem.tokenizeScalar(u8, input, ',');
    while (it.next()) |token| {
        const len = try std.fmt.parseInt(usize, token, 10);
        hsh.step(len);
    }
    return @as(u32, hsh.buf[0]) * @as(u32, hsh.buf[1]);
}

const KnotHash = struct {
    buf: []u8,
    pos: usize = 0,
    skip: usize = 0,

    fn step(self: *KnotHash, len: usize) void {
        for (0..@divFloor(len, 2)) |i| {
            const j = len - 1 - i;
            const a = (self.pos + i) % self.buf.len;
            const b = (self.pos + j) % self.buf.len;
            const tmp = self.buf[a];
            self.buf[a] = self.buf[b];
            self.buf[b] = tmp;
        }
        self.pos += len;
        self.pos += self.skip;
        self.pos %= self.buf.len;
        self.skip += 1;
    }
};

test KnotHash {
    var buf: [5]u8 = .{ 0, 1, 2, 3, 4 };
    const lengths: []const usize = &.{ 3, 4, 1, 5 };
    var hsh: KnotHash = .{ .buf = &buf };
    for (lengths) |len| hsh.step(len);
    try std.testing.expectEqual(4, hsh.pos);
    try std.testing.expectEqualSlices(u8, &.{ 3, 4, 2, 1, 0 }, hsh.buf);
    try std.testing.expectEqual(4, hsh.skip);
}
