const std = @import("std");

pub fn process(gpa: std.mem.Allocator, input: []const u8) !usize {
    var set: Set = .empty;
    defer set.deinit(gpa);
    try set.append(gpa, 0);
    try accumulate(gpa, &set, input, 0);
    return set.items.len;
}

const Set = std.ArrayListUnmanaged(usize);

fn accumulate(gpa: std.mem.Allocator, set: *Set, input: []const u8, index: usize) !void {
    const initial_len = set.items.len;
    const line = line: {
        var pos: usize = 0;
        for (0..index) |_| {
            pos = std.mem.indexOfScalarPos(u8, input, pos, '\n').? + 1;
        }
        const line_end = std.mem.indexOfScalarPos(u8, input, pos, '\n') orelse input.len;
        const line = input[pos..line_end];
        const divider = " <-> ";
        const idx = std.mem.indexOf(u8, line, divider) orelse {
            std.log.err("bad input: {s}", .{line});
            return error.MissingDivider;
        };
        break :line line[idx + divider.len ..];
    };
    var it = std.mem.tokenizeSequence(u8, line, ", ");
    while (it.next()) |token| {
        errdefer std.log.err("bad token: {s}", .{token});
        const value = try std.fmt.parseInt(usize, token, 10);
        if (std.mem.indexOfScalar(usize, set.items, value) != null) continue;
        try set.append(gpa, value);
    }
    const new_len = set.items.len;
    for (initial_len..new_len) |i| {
        try accumulate(gpa, set, input, set.items[i]);
    }
}

test process {
    const input =
        \\0 <-> 2
        \\1 <-> 1
        \\2 <-> 0, 3, 4
        \\3 <-> 2, 4
        \\4 <-> 2, 3, 6
        \\5 <-> 6
        \\6 <-> 4, 5
    ;
    try std.testing.expectEqual(6, process(std.testing.allocator, input));
}
