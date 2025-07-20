const std = @import("std");

pub fn process(_: std.mem.Allocator, input: []const u8) ![32]u8 {
    var buf: [256]u8 = undefined;
    for (&buf, 0..) |*ptr, i| ptr.* = @intCast(i);
    var hsh: KnotHash = .{ .buf = &buf };
    const in = std.mem.trimEnd(u8, input, &.{ 0, '\n' });
    for (0..64) |_| {
        for (in) |byte| hsh.step(byte);
        const suffix: []const usize = &.{ 17, 31, 73, 47, 23 };
        for (suffix) |len| hsh.step(len);
    }
    var dense_hash: [32]u8 = undefined;
    for (0..16) |i| {
        var byte: u8 = 0;
        for (hsh.buf[i * 16 ..][0..16]) |other| byte ^= other;
        var w: std.io.Writer = .{
            .buffer = dense_hash[i * 2 ..][0..2],
            .vtable = &.{
                .drain = std.io.Writer.failingDrain,
                .sendFile = std.io.Writer.failingSendFile,
            },
        };
        try w.printInt(byte, 16, .lower, .{ .width = 2, .fill = '0' });
    }
    return dense_hash;
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
    const input: []const []const u8 = &.{
        &.{},
        "AoC 2017",
        "1,2,3",
        "1,2,4",
    };
    const output: []const [32]u8 = &.{ "a2582a3a0e66e6e86e3812dcb672a272".*, "33efeb34ea91902bb2f59c9920caa6cd".*, "3efbe78a8d82f29979031a4aa0b16a9d".*, "63960835bcdc130f0b66d7ff4f6a5a8e".* };
    for (input, output) |in, expected|
        try std.testing.expectEqual(expected, try process(std.testing.allocator, in));
}
