const std = @import("std");

pub const std_options: std.Options = .{
    .log_level = .err,
};

const Registers = std.AutoHashMapUnmanaged(u8, i64);

const Instruction = enum {
    snd,
    set,
    add,
    mul,
    mod,
    rcv,
    jgz,

    fn parse(line: []const u8) !Instruction {
        errdefer std.log.err("{s}", .{line});
        inline for (&.{ "snd", "set", "add", "mul", "mod", "rcv", "jgz" }) |name| {
            if (std.mem.startsWith(u8, line, name)) return @field(Instruction, name);
        }
        return error.ParseError;
    }
};

pub fn process(gpa: std.mem.Allocator, input: []const u8) !i64 {
    var registers: Registers = .empty;
    defer registers.deinit(gpa);

    var pc: i64 = 0;
    const len = len: {
        var len: i64 = 0;
        for (input) |byte| {
            if (byte == '\n') len += 1;
        }
        if (input[input.len - 1] != '\n') len += 1;
        break :len len;
    };
    errdefer std.log.err("len: {d}", .{len});
    var snd: i64 = 0;
    while (0 <= pc and pc < len) {
        errdefer std.log.err("pc: {d}", .{pc});
        const line = nThLine(input, @intCast(pc));
        std.log.debug("{s}", .{line});
        errdefer std.log.err("line: {s}", .{line});
        const instruction: Instruction = try .parse(line);
        const reg = line[4];
        switch (instruction) {
            .set, .add, .mul, .mod => {
                const value = std.fmt.parseInt(i64, line[6..], 10) catch val: {
                    const gop = try registers.getOrPut(gpa, line[6]);
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    break :val gop.value_ptr.*;
                };
                const curr = try registers.getOrPut(gpa, reg);
                if (!curr.found_existing) curr.value_ptr.* = 0;
                switch (instruction) {
                    .set => curr.value_ptr.* = value,
                    .add => curr.value_ptr.* += value,
                    .mod => curr.value_ptr.* = @mod(curr.value_ptr.*, value),
                    .mul => curr.value_ptr.* *= value,
                    else => unreachable,
                }
            },
            .snd => {
                const sound = std.fmt.parseInt(i64, line[4..], 10) catch val: {
                    const gop = try registers.getOrPut(gpa, reg);
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    break :val gop.value_ptr.*;
                };
                std.log.debug("sound: {d}", .{sound});
                snd = sound;
            },
            .rcv => {
                const value = std.fmt.parseInt(i64, line[4..], 10) catch val: {
                    const gop = try registers.getOrPut(gpa, reg);
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    break :val gop.value_ptr.*;
                };
                if (value > 0) return snd;
            },
            .jgz => {
                const space = std.mem.indexOfScalarPos(u8, line, 4, ' ').?;
                const x = std.fmt.parseInt(i64, line[4..space], 10) catch val: {
                    const gop = try registers.getOrPut(gpa, reg);
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    break :val gop.value_ptr.*;
                };
                const y = std.fmt.parseInt(i64, line[space + 1 ..], 10) catch val: {
                    const gop = try registers.getOrPut(gpa, line[space + 1]);
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    break :val gop.value_ptr.*;
                };
                if (x > 0) {
                    pc += y;
                    continue;
                }
            },
        }
        pc += 1;
    }
    unreachable;
}

fn nThLine(input: []const u8, n: usize) []const u8 {
    if (n == 0) return input[0..std.mem.indexOfScalar(u8, input, '\n').?];
    var idx: usize = 0;
    for (0..n) |_| {
        idx = std.mem.indexOfScalarPos(u8, input, idx + 1, '\n').?;
    }
    if (std.mem.indexOfScalarPos(u8, input, idx + 1, '\n')) |end| return input[idx + 1 .. end];
    return input[idx + 1 ..];
}

test process {
    std.testing.log_level = .debug;
    const input =
        \\set a 1
        \\add a 2
        \\mul a a
        \\mod a 5
        \\snd a
        \\set a 0
        \\rcv a
        \\jgz a -1
        \\set a 1
        \\jgz a -2
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(4, output);
}
