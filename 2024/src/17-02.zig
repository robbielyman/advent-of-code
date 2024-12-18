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
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var i_reg: [3]u64 = undefined;
    var program: std.ArrayListUnmanaged(u3) = .{};
    defer program.deinit(allocator);
    const register_starts: []const []const u8 = &.{
        "Register A: ",
        "Register B: ",
        "Register C: ",
    };
    const program_start = "Program: ";
    for (register_starts, &i_reg) |needle, *val| {
        const idx = std.mem.indexOf(u8, input, needle) orelse return error.BadInput;
        const end = std.mem.indexOfScalarPos(u8, input, idx, '\n') orelse return error.BadInput;
        val.* = try std.fmt.parseInt(u64, input[idx + needle.len .. end], 10);
    }
    {
        var idx = (std.mem.indexOf(u8, input, program_start) orelse return error.BadInput) + program_start.len;
        while (idx < input.len and input[idx] != '\n') : (idx += 2) {
            try program.append(allocator, try std.fmt.parseInt(u3, input[idx..][0..1], 10));
        }
    }

    return try solve(allocator, i_reg, program.items);
}

fn solve(allocator: std.mem.Allocator, i_reg: [3]u64, program: []const u3) !u64 {
    const cache = try allocator.alloc(u3, 1 << 10);
    defer allocator.free(cache);

    for (cache, 0..) |*ptr, i| {
        ptr.* = try produce(@intCast(i), i_reg, program);
    }

    var output: std.ArrayListUnmanaged(u10) = .{};
    defer output.deinit(allocator);
    const seeds = try allocator.alloc(u10, program.len);
    defer allocator.free(seeds);
    @memset(seeds, 0);
    while (output.items.len < program.len) {
        var i: usize = seeds[output.items.len];
        while (i < cache.len) {
            const out = cache[i];
            if (out != program[output.items.len]) {
                i += 1;
                continue;
            }
            if (output.items.len > 0 and i % (1 << 7) != output.items[output.items.len - 1] >> 3) {
                i += 1;
                continue;
            }
            if (output.items.len > 1 and i % (1 << 4) != output.items[output.items.len - 2] >> 6) {
                i += 1;
                continue;
            }
            if (output.items.len > 2 and i % (1 << 1) != output.items[output.items.len - 3] >> 9) {
                i += 1;
                continue;
            }
            if (output.items.len + 1 == program.len and i >> 3 != 0) {
                i += 1;
                continue;
            }
            try output.append(allocator, @intCast(i));
            break;
        } else {
            // backtrack
            @memcpy(seeds[0..output.items.len], output.items);
            @memset(seeds[output.items.len..], 0);
            output.items.len -= 1;
            seeds[output.items.len] += 1;
        }
    }
    var buf: [1024]u8 = undefined;
    for (0..output.items.len) |i| {
        const k = output.items.len - 1 - i;
        const bits = output.items[k];
        var scratch: [10]u8 = undefined;
        _ = try std.fmt.bufPrint(&scratch, "{b:0>10}", .{bits});
        std.mem.reverse(u8, &scratch);
        @memcpy(buf[3 * k ..][0..10], &scratch);
    }
    std.mem.reverse(u8, buf[0..48]);
    return try std.fmt.parseInt(u64, buf[0..48], 2);
}

fn produce(a: u64, i_reg: [3]u64, program: []const u3) !u3 {
    var ip: usize = 0;
    var reg: [3]u64 = .{ a, i_reg[1], i_reg[2] };
    while (ip < program.len - 1) {
        const op: OpCode = @enumFromInt(program[ip]);
        const operand = program[ip + 1];
        const output = try op.act(operand, &reg, &ip);
        return output orelse continue;
    }
    return error.NeverOutput;
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
