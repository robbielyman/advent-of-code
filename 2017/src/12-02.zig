const std = @import("std");

pub fn process(gpa: std.mem.Allocator, input: []const u8) !usize {
    const len = len: {
        var len: usize = 0;
        for (input) |byte| {
            if (byte == '\n') len += 1;
        }
        break :len if (input[input.len - 1] == '\n') len else len + 1;
    };
    var seen: Seen = .empty;
    defer seen.deinit(gpa);
    var set: Set = .empty;
    defer set.deinit(gpa);
    var ret: usize = 0;
    while (seen.size < len) : (ret += 1) {
        set.clearRetainingCapacity();
        var next: usize = 0;
        while (true) : (next += 1) if (!seen.contains(next)) break;
        try set.append(gpa, next);
        try accumulate(gpa, &set, input, next);
        for (set.items) |key| try seen.putNoClobber(gpa, key, {});
    }
    return ret;
}

const Seen = std.AutoHashMapUnmanaged(usize, void);

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
    try std.testing.expectEqual(2, process(std.testing.allocator, input));
}
