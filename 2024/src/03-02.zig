const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("03.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer = try std.time.Timer.start();
    const output = process(input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) i32 {
    const max_instruction_len = 3 + 1 + 3 + 1 + 3 + 1; // "mul" + "(" + xxx + "," ++ "yyy" + ")"
    var output: i32 = 0;
    var idx: usize = 0;
    var enabled: enum { enabled, disabled } = .enabled;
    while (idx < input.len)
        switch (enabled) {
            .disabled => {
                idx = std.mem.indexOfPos(u8, input, idx, "do()") orelse break;
                enabled = .enabled;
            },
            .enabled => {
                const disabled = std.mem.indexOfPos(u8, input, idx, "don't()");
                const mul = std.mem.indexOfPos(u8, input, idx, "mul") orelse break; // no mul instructions left!
                if (disabled) |d| if (d < mul) {
                    enabled = .disabled;
                    idx = d;
                    continue;
                };
                idx = mul + 1;
                const a, const b = validate: {
                    const end = @min(mul + max_instruction_len, input.len);
                    const slice = input[mul..end];
                    if (!std.mem.startsWith(u8, slice, "mul(")) continue; // ) emacs shut up
                    const comma = std.mem.indexOfScalar(u8, slice, ',') orelse continue;
                    if (comma > 8) continue;
                    const a = std.fmt.parseInt(i32, slice["mul(".len..comma], 10) catch continue;
                    const paren = std.mem.indexOfScalarPos(u8, slice, comma, ')') orelse continue;
                    if (paren - comma > 4) continue;
                    const b = std.fmt.parseInt(i32, slice[comma + 1 .. paren], 10) catch continue;
                    break :validate .{ a, b };
                };
                output += a * b;
            },
        };
    return output;
}

test {
    const input = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
    const output = process(input);
    try std.testing.expectEqual(48, output);
}
