const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("17.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input);
    defer allocator.free(output);
    const elapsed = timer.read();

    try stdout.print("{s}\nlen: {}\n", .{ output, output.len });
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var registers: [3]u64 = undefined;
    var ip: usize = 0;
    var program: std.ArrayListUnmanaged(u3) = .{};
    defer program.deinit(allocator);
    const register_starts: []const []const u8 = &.{
        "Register A: ",
        "Register B: ",
        "Register C: ",
    };
    const program_start = "Program: ";
    for (register_starts, &registers) |needle, *val| {
        const idx = std.mem.indexOf(u8, input, needle) orelse return error.BadInput;
        const end = std.mem.indexOfScalarPos(u8, input, idx, '\n') orelse return error.BadInput;
        val.* = try std.fmt.parseInt(u64, input[idx + needle.len .. end], 10);
    }
    var idx = (std.mem.indexOf(u8, input, program_start) orelse return error.BadInput) + program_start.len;
    while (idx < input.len and input[idx] != '\n') : (idx += 2) {
        try program.append(allocator, try std.fmt.parseInt(u3, input[idx..][0..1], 10));
    }

    var output: std.ArrayListUnmanaged(u8) = .{};
    defer output.deinit(allocator);

    while (ip < program.items.len) {
        const op: OpCode = @enumFromInt(program.items[ip]);
        const operand = program.items[ip + 1];
        const val: u8 = try op.act(operand, &registers, &ip) orelse continue;
        if (output.items.len > 0) try output.append(allocator, ',');
        try output.append(allocator, '0' + val);
    }
    return try output.toOwnedSlice(allocator);
}

const OpCode = enum(u3) {
    adv,
    bxl,
    bst,
    jnz,
    bxc,
    out,
    bdv,
    cdv,

    fn act(op: OpCode, operand: u3, registers: *[3]u64, ip: *usize) !?u3 {
        switch (op) {
            .adv, .bdv, .cdv => |val| {
                const num = registers[0];
                const denom: u64 = switch (operand) {
                    0...3 => |i| std.math.pow(u64, 2, i),
                    4...6 => |j| std.math.pow(u64, 2, registers[j - 4]),
                    7 => return error.InvalidProgram,
                };
                const idx: usize = switch (val) {
                    .adv => 0,
                    .bdv => 1,
                    .cdv => 2,
                    else => unreachable,
                };
                registers[idx] = @divTrunc(num, denom);
                ip.* += 2;
            },
            .bxl => {
                registers[1] ^= operand;
                ip.* += 2;
            },
            .bst => {
                registers[1] = switch (operand) {
                    0...3 => |i| i,
                    4...6 => |j| registers[j - 4] % 8,
                    7 => return error.InvalidProgram,
                };
                ip.* += 2;
            },
            .jnz => ip.* = if (registers[0] == 0)
                ip.* + 2
            else
                operand,
            .bxc => {
                registers[1] ^= registers[2];
                ip.* += 2;
            },
            .out => {
                ip.* += 2;
                return switch (operand) {
                    0...3 => |i| i,
                    4...6 => |j| @intCast(registers[j - 4] % 8),
                    7 => error.InvalidProgram,
                };
            },
        }
        return null;
    }
};

test {
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    const output = try process(std.testing.allocator, input);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("4,6,3,5,6,3,5,2,1,0", output);
}
