const std = @import("std");

pub fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var set: Set = .empty;
    defer {
        for (set.keys()) |key| allocator.free(key);
        set.deinit(allocator);
    }
    const current = try parse(allocator, input);
    defer allocator.free(current);
    var count: usize = 0;
    while (true) : (count += 1) {
        const put = try allocator.dupe(u32, current);
        const ret = try set.getOrPut(allocator, put);
        if (ret.found_existing) {
            allocator.free(put);
            break;
        }
        var idx = std.mem.indexOfMax(u32, current);
        var left = current[idx];
        current[idx] = 0;
        while (left > 0) : (left -= 1) {
            idx = (idx + 1) % current.len;
            current[idx] += 1;
        }
    }
    return count;
}

fn parse(allocator: std.mem.Allocator, input: []const u8) ![]u32 {
    var list: std.ArrayListUnmanaged(u32) = .empty;
    defer list.deinit(allocator);
    var it = std.mem.tokenizeAny(u8, input, " \t\r\n");
    while (it.next()) |token| {
        const number = try std.fmt.parseInt(u32, token, 10);
        try list.append(allocator, number);
    }
    return try list.toOwnedSlice(allocator);
}

const Ctx = struct {
    pub const hash = std.array_hash_map.getAutoHashStratFn([]const u32, @This(), .Deep);
    pub fn eql(_: Ctx, a: []const u32, b: []const u32, _: usize) bool {
        return std.mem.eql(u32, a, b);
    }
};

const Set = std.ArrayHashMapUnmanaged([]const u32, void, Ctx, true);

test process {
    const input = "0 2 7 0";
    try std.testing.expectEqual(5, process(std.testing.allocator, input));
}
