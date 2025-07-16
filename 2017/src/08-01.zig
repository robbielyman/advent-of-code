const std = @import("std");

const Registry = std.StringArrayHashMapUnmanaged(i32);
const Condition = enum {
    eq,
    neq,
    lt,
    gt,
    leq,
    geq,

    fn exec(cond: Condition, lhs: *const i32, rhs: i32) bool {
        return switch (cond) {
            .eq => lhs.* == rhs,
            .neq => lhs.* != rhs,
            .lt => lhs.* < rhs,
            .gt => lhs.* > rhs,
            .leq => lhs.* <= rhs,
            .geq => lhs.* >= rhs,
        };
    }

    fn parse(buf: []const u8) !Condition {
        if (buf.len == 0 or buf.len > 2) return error.Invalid;
        return switch (buf[0]) {
            '!' => if (buf.len == 2 and buf[1] == '=') .neq else error.Invalid,
            '=' => if (buf.len == 2 and buf[1] == '=') .eq else error.Invalid,
            '<' => if (buf.len == 1) .lt else if (buf.len == 2 and buf[1] == '=') .leq else error.Invalid,
            '>' => if (buf.len == 1) .gt else if (buf.len == 2 and buf[1] == '=') .geq else error.Invalid,
            else => error.Invalid,
        };
    }
};

const Command = enum {
    inc,
    dec,

    fn exec(cmd: Command, lhs: *i32, rhs: i32) void {
        switch (cmd) {
            .inc => lhs.* += rhs,
            .dec => lhs.* -= rhs,
        }
    }

    fn parse(buf: []const u8) !Command {
        return if (std.mem.eql(u8, buf, "inc"))
            .inc
        else if (std.mem.eql(u8, buf, "dec"))
            .dec
        else
            error.Invalid;
    }
};

pub fn process(allocator: std.mem.Allocator, input: []const u8) !i32 {
    var registry: Registry = .empty;
    defer registry.deinit(allocator);
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        var splitter = std.mem.tokenizeScalar(u8, line, ' ');
        var res: [7][]const u8 = undefined;
        for (&res) |*token| token.* = splitter.next().?;
        const lhs, const cmd, const rhs, _, const cond_lhs, const cond, const cond_rhs = res;

        const gop_2 = try registry.getOrPut(allocator, cond_lhs);
        if (!gop_2.found_existing) gop_2.value_ptr.* = 0;
        const c: Condition = try .parse(cond);
        if (!c.exec(gop_2.value_ptr, try std.fmt.parseInt(i32, cond_rhs, 10))) continue;

        const gop = try registry.getOrPut(allocator, lhs);
        if (!gop.found_existing) gop.value_ptr.* = 0;
        const cm: Command = try .parse(cmd);
        cm.exec(gop.value_ptr, try std.fmt.parseInt(i32, rhs, 10));
    }
    var ret: i32 = std.math.minInt(i32);
    for (registry.values()) |val| {
        ret = @max(ret, val);
    }
    return ret;
}

test process {
    const input =
        \\b inc 5 if a > 1
        \\a inc 1 if b < 5
        \\c dec -10 if a >= 1
        \\c inc -20 if c == 10
    ;
    try std.testing.expectEqual(1, try process(std.testing.allocator, input));
}
