pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    const file = try std.fs.cwd().openFile("05.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var timer: std.time.Timer = try .start();
    const output = try process(allocator, input);
    const elapsed = timer.lap();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

const Walker = struct {
    data: []i32,
    index: i32,

    fn next(self: *Walker) ?void {
        if (self.index < 0 or @as(usize, @intCast(self.index)) >= self.data.len) return null;
        const delta = &self.data[@intCast(self.index)];
        self.index += delta.*;
        if (delta.* >= 3) delta.* -= 1 else delta.* += 1;
    }
};

fn process(allocator: std.mem.Allocator, input: []const u8) !u32 {
    var list: std.ArrayListUnmanaged(i32) = .empty;
    defer list.deinit(allocator);
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |token| {
        try list.append(allocator, try std.fmt.parseInt(i32, token, 10));
    }

    var ret: u32 = 0;
    var walker: Walker = .{ .data = list.items, .index = 0 };
    while (walker.next()) |_| ret += 1;
    return ret;
}

test {
    const input: []const u8 =
        \\0
        \\3
        \\0
        \\1
        \\-3
    ;
    try std.testing.expectEqual(10, try process(std.testing.allocator, input));
}

const std = @import("std");
