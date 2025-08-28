const std = @import("std");

pub fn process(gpa: std.mem.Allocator, input: []const u8) !u32 {
    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(gpa);
    const token = std.mem.trimEnd(u8, input, &.{ 0, '\n' });
    const step_size = try std.fmt.parseInt(usize, token, 10);
    try list.append(gpa, 0);
    var idx: usize = 0;
    for (1..2018) |i| {
        idx += step_size;
        idx %= list.items.len;
        try list.insert(gpa, idx + 1, @intCast(i));
        idx += 1;
    }
    return list.items[idx + 1];
}

test process {
    const input = "3";
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(638, output);
}
