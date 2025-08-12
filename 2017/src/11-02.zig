const std = @import("std");

pub fn process(gpa: std.mem.Allocator, input: []const u8) !usize {
    var list: std.ArrayListUnmanaged(Direction) = .empty;
    defer list.deinit(gpa);
    var it = std.mem.tokenizeScalar(u8, input, ',');
    var ret: usize = 0;
    while (it.next()) |token| {
        const tok: Direction = tok: switch (token[0]) {
            'n' => {
                if (token.len == 1) break :tok .n;
                break :tok switch (token[1]) {
                    'e' => .ne,
                    'w' => .nw,
                    else => return error.ParseFailure,
                };
            },
            's' => {
                if (token.len == 1) break :tok .s;
                break :tok switch (token[1]) {
                    'e' => .se,
                    'w' => .sw,
                    else => return error.ParseFailure,
                };
            },
            '\n' => break,
            else => return error.ParseFailed,
        };
        try list.append(gpa, tok);
        list.items = Direction.reduce(list.items).items;
        ret = @max(ret, list.items.len);
    }

    return ret;
}

const Direction = enum {
    nw,
    n,
    ne,
    se,
    s,
    sw,

    inline fn reducers(self: Direction) [3]Direction {
        return switch (self) {
            .nw => .{ .ne, .se, .s },
            .n => .{ .se, .s, .sw },
            .ne => .{ .nw, .s, .sw },
            .se => .{ .nw, .n, .sw },
            .s => .{ .nw, .n, .ne },
            .sw => .{ .ne, .n, .se },
        };
    }

    fn inverse(self: Direction) Direction {
        return switch (self) {
            .nw => .se,
            .n => .s,
            .ne => .sw,
            .se => .nw,
            .s => .n,
            .sw => .ne,
        };
    }

    fn replace(a: Direction, b: Direction) ?Direction {
        return switch (a) {
            .nw => switch (b) {
                .ne => .n,
                .s => .sw,
                else => null,
            },
            .n => switch (b) {
                .se => .ne,
                .sw => .nw,
                else => null,
            },
            .ne => switch (b) {
                .nw => .n,
                .s => .se,
                else => null,
            },
            .sw => switch (b) {
                .se => .s,
                .n => .nw,
                else => null,
            },
            .s => switch (b) {
                .ne => .se,
                .nw => .sw,
                else => null,
            },
            .se => switch (b) {
                .sw => .s,
                .n => .ne,
                else => null,
            },
        };
    }

    fn reduce(buf: []Direction) std.ArrayListUnmanaged(Direction) {
        var list: std.ArrayListUnmanaged(Direction) = .{
            .items = buf,
            .capacity = buf.len,
        };
        var idx: usize = 0;
        while (idx < list.items.len) {
            const current = list.items[idx];
            const pair = std.mem.indexOfAnyPos(Direction, list.items, idx + 1, &current.reducers()) orelse {
                idx += 1;
                continue;
            };
            if (list.items[pair] == current.inverse()) {
                _ = list.orderedRemove(pair);
            } else {
                list.items[pair] = current.replace(list.items[pair]).?;
            }
            _ = list.orderedRemove(idx);
        }
        return list;
    }
};

test Direction {
    const inputs: []const []const Direction = &.{
        &.{ .ne, .ne, .ne },
        &.{ .ne, .ne, .sw, .sw },
        &.{ .ne, .ne, .s, .s },
        &.{ .se, .sw, .se, .sw, .sw },
    };
    const expectations: []const usize = &.{ 3, 0, 2, 3 };
    for (inputs, expectations) |input, expected| {
        const buf = try std.testing.allocator.dupe(Direction, input);
        defer std.testing.allocator.free(buf);
        const got = Direction.reduce(buf);
        errdefer std.log.err("in: {any}", .{input});
        errdefer std.log.err("got: {any}", .{got.items});
        try std.testing.expectEqual(expected, got.items.len);
    }
}

test process {
    const inputs: []const []const u8 = &.{
        "ne,ne,ne",
        "ne,ne,sw,sw",
        "ne,ne,s,s",
        "se,sw,se,sw,sw",
    };
    const expectations: []const usize = &.{ 3, 0, 2, 3 };
    for (inputs, expectations) |input, expected|
        try std.testing.expectEqual(expected, try process(std.testing.allocator, input));
}
