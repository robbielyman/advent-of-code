const std = @import("std");

pub const std_options: std.Options = .{
    .log_level = .err,
};

const Registers = std.AutoHashMapUnmanaged(u8, i64);
const Queue = std.ArrayList(i64);

const Program = struct {
    status: enum { running, blocked, halted } = .running,
    pc: i64 = 0,
    registers: Registers = .empty,
    queue: Queue = .empty,

    fn deinit(self: *Program, gpa: std.mem.Allocator) void {
        self.registers.deinit(gpa);
        self.queue.deinit(gpa);
        self.* = undefined;
    }

    fn run(self: *Program, gpa: std.mem.Allocator, other: *Queue, lines: []const []const u8) !usize {
        var count: usize = 0;
        self.status = status: switch (self.status) {
            .halted => .halted,
            .blocked => if (self.queue.items.len > 0) continue :status .running else .blocked,
            .running => {
                if (self.pc < 0) continue :status .halted;
                const pc: usize = @intCast(self.pc);
                if (pc >= lines.len) continue :status .halted;
                const instruction: Instruction = try .parse(lines[pc]);
                const reg = lines[pc][4];
                switch (instruction) {
                    .set, .add, .mul, .mod => {
                        const value = std.fmt.parseInt(i64, lines[pc][6..], 10) catch val: {
                            const gop = try self.registers.getOrPut(gpa, lines[pc][6]);
                            if (!gop.found_existing) gop.value_ptr.* = 0;
                            break :val gop.value_ptr.*;
                        };
                        const curr = try self.registers.getOrPut(gpa, reg);
                        if (!curr.found_existing) curr.value_ptr.* = 0;
                        switch (instruction) {
                            .set => curr.value_ptr.* = value,
                            .add => curr.value_ptr.* += value,
                            .mod => curr.value_ptr.* = @mod(curr.value_ptr.*, value),
                            .mul => curr.value_ptr.* *= value,
                            else => unreachable,
                        }
                    },
                    .jgz => {
                        const space = std.mem.indexOfScalarPos(u8, lines[pc], 4, ' ').?;
                        const x = std.fmt.parseInt(i64, lines[pc][4..space], 10) catch val: {
                            const gop = try self.registers.getOrPut(gpa, reg);
                            if (!gop.found_existing) gop.value_ptr.* = 0;
                            break :val gop.value_ptr.*;
                        };
                        const y = std.fmt.parseInt(i64, lines[pc][space + 1 ..], 10) catch val: {
                            const gop = try self.registers.getOrPut(gpa, lines[pc][space + 1]);
                            if (!gop.found_existing) gop.value_ptr.* = 0;
                            break :val gop.value_ptr.*;
                        };
                        if (x > 0) {
                            self.pc += y;
                            continue :status .running;
                        }
                    },
                    .snd => {
                        const value = std.fmt.parseInt(i64, lines[pc][4..], 10) catch val: {
                            const gop = try self.registers.getOrPut(gpa, reg);
                            if (!gop.found_existing) gop.value_ptr.* = 0;
                            break :val gop.value_ptr.*;
                        };
                        try other.append(gpa, value);
                        count += 1;
                    },
                    .rcv => {
                        if (self.queue.items.len == 0) continue :status .blocked;
                        const value = self.queue.orderedRemove(0);
                        try self.registers.put(gpa, reg, value);
                    },
                }
                self.pc += 1;
                continue :status .running;
            },
        };
        return count;
    }
};

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

pub fn process(gpa: std.mem.Allocator, input: []const u8) !usize {
    var lines: std.ArrayList([]const u8) = .empty;
    defer lines.deinit(gpa);
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| try lines.append(gpa, line);

    var zero: Program = .{};
    defer zero.deinit(gpa);
    try zero.registers.put(gpa, 'p', 0);
    var one: Program = .{};
    defer one.deinit(gpa);
    try one.registers.put(gpa, 'p', 1);

    var count: usize = 0;
    while (true) {
        _ = try zero.run(gpa, &one.queue, lines.items);
        count += try one.run(gpa, &zero.queue, lines.items);
        if (zero.status == .blocked and zero.queue.items.len > 0) continue;
        if (one.status == .blocked and one.queue.items.len > 0) continue;
        break;
    }
    return count;
}

test process {
    std.testing.log_level = .debug;
    const input =
        \\snd 1
        \\snd 2
        \\snd p
        \\rcv a
        \\rcv b
        \\rcv c
        \\rcv d
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(3, output);
}
