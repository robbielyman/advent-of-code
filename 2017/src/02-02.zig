pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    const file = try std.fs.cwd().openFile("02.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer: std.time.Timer = try .start();
    const output = try process(input);
    const elapsed = timer.lap();

    try stdout.print("{}\n", .{output});
    try stdout.print("{}us elapsed\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) !u32 {
    var ret: u32 = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    lines: while (lines.next()) |line| {
        var outer = std.mem.tokenizeAny(u8, line, " \t");
        while (outer.next()) |token| {
            const first = try std.fmt.parseInt(u32, token, 10);
            var inner = std.mem.tokenizeAny(u8, line[0 .. outer.index - token.len], " \t");
            while (inner.next()) |tok| {
                const second = try std.fmt.parseInt(u32, tok, 10);
                if (first % second == 0) {
                    ret += @divExact(first, second);
                    continue :lines;
                }
                if (second % first == 0) {
                    ret += @divExact(second, first);
                    continue :lines;
                }
            }
        }
        unreachable;
    }
    return ret;
}

test {
    std.testing.log_level = .debug;
    const input =
        \\5 9 2 8
        \\9 4 7 3
        \\3 8 6 5
    ;
    const output = try process(input);
    try std.testing.expectEqual(9, output);
}

const std = @import("std");
