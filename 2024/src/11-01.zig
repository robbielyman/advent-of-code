const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const file = try std.fs.cwd().openFile("11.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var list: std.ArrayListUnmanaged(DigitString) = .{};
    defer list.deinit(allocator);

    var iter = std.mem.tokenizeAny(u8, input, " \n");
    while (iter.next()) |token| {
        const number = try std.fmt.parseInt(usize, token, 10);
        try list.append(allocator, try DigitString.fromNumber(number));
    }

    for (0..25) |_| {
        const slice = try list.toOwnedSlice(allocator);
        defer allocator.free(slice);
        for (slice) |item| {
            try item.yieldChildren(allocator, &list);
        }
    }
    return list.items.len;
}

const DigitString = struct {
    data: [24]u8,

    const empty: DigitString = .{ .data = .{0} ** 24 };
    const one: DigitString = .{ .data = .{'1'} ++ (.{0} ** 23) };

    fn slice(self: *const DigitString) ![:0]const u8 {
        const zero = std.mem.indexOfScalar(u8, &self.data, 0) orelse return error.BadData;
        return self.data[0..zero :0];
    }

    fn toNumber(self: *const DigitString) !usize {
        return try std.fmt.parseInt(usize, try self.slice(), 10);
    }

    fn fromNumber(digit: usize) !DigitString {
        var self: DigitString = empty;
        _ = try std.fmt.bufPrint(&self.data, "{d}", .{digit});
        return self;
    }

    fn yieldChildren(string: DigitString, allocator: std.mem.Allocator, list: *std.ArrayListUnmanaged(DigitString)) !void {
        const number = try string.toNumber();
        if (number == 0) return try list.append(allocator, one);
        const str = try string.slice();
        if (str.len % 2 == 0) return {
            const a = try std.fmt.parseInt(usize, str[0 .. str.len / 2], 10);
            try list.append(allocator, try fromNumber(a));
            const b = try std.fmt.parseInt(usize, str[str.len / 2 ..], 10);
            try list.append(allocator, try fromNumber(b));
        };
        try list.append(allocator, try fromNumber(number * 2024));
    }
};

test {
    const input = "125 17";
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(55312, output);
}
