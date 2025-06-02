const std = @import("std");

pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .{};
    defer _ = dba.deinit();
    const allocator = dba.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const input = args[1];

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();

    var timer: std.time.Timer = try .start();
    const output = try process(input);
    const elapsed = timer.lap();

    try stdout.print("{}\n", .{output});
    try stdout.print("time elapsed: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

const Spiraler = struct {
    x: Bounds,
    y: Bounds,
    current: struct {
        x: i32,
        y: i32,
        direction: Ortho,
    },

    pub const init: Spiraler = .{
        .x = .zero,
        .y = .zero,
        .current = .{ .x = 0, .y = 0, .direction = .right },
    };

    const Ortho = enum {
        up,
        down,
        left,
        right,
        fn update(self: *Ortho) void {
            self.* = switch (self.*) {
                .up => .left,
                .left => .down,
                .down => .right,
                .right => .up,
            };
        }
    };

    const Bounds = struct {
        min: i32,
        max: i32,

        pub const zero: @This() = .{ .min = 0, .max = 0 };

        fn update(self: *@This(), val: i32) bool {
            if (val < self.min or val > self.max) {
                self.min = @min(self.min, val);
                self.max = @max(self.max, val);
                return true;
            }
            return false;
        }
    };

    pub fn next(self: *Spiraler) struct { x: i32, y: i32 } {
        const dx: i32, const dy: i32 = switch (self.current.direction) {
            .up => .{ 0, 1 },
            .down => .{ 0, -1 },
            .left => .{ -1, 0 },
            .right => .{ 1, 0 },
        };
        self.current.x += dx;
        self.current.y += dy;
        if (self.x.update(self.current.x) or self.y.update(self.current.y)) self.current.direction.update();
        return .{ .x = self.current.x, .y = self.current.y };
    }
};

fn process(input: []const u8) !i64 {
    const n = try std.fmt.parseInt(u32, input, 10);
    var i: u32 = 1;
    var it: Spiraler = .init;
    while (i < n) : (i += 1) {
        _ = it.next();
    }
    return @abs(it.current.x) + @abs(it.current.y);
}

test process {
    const inputs: []const []const u8 = &.{ "1", "12", "23", "1024" };
    const expected: []const i64 = &.{ 0, 3, 2, 31 };
    for (inputs, expected) |input, expectation| try std.testing.expectEqual(expectation, try process(input));
}
