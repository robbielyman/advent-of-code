const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = try parseArgs(allocator);
    const contents = try getFileContents(filename, allocator);
    defer allocator.free(contents);
    allocator.free(filename);
    var tokenizer = std.mem.splitScalar(u8, contents, '\n');
    var count: usize = 0;
    var map = Map.init(allocator);
    defer map.deinit();
    while (tokenizer.next()) |line| {
        if (line.len == 0) break;
        try addToMap(line, &map);
    }
    const node = try allocator.create(Queue.Node);
    node.* = .{ .part = .{
        .x = .{ .min = 1, .max = 4000 },
        .m = .{ .min = 1, .max = 4000 },
        .a = .{ .min = 1, .max = 4000 },
        .s = .{ .min = 1, .max = 4000 },
    } };
    const queue = map.getPtr("in") orelse return error.ParseFailed;
    queue.addToTail(node);
    while (!(try stepThrough(&map, &count, allocator))) {}

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn getFileContents(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 32 * 1024);
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

const Part = struct {
    x: Range,
    m: Range,
    a: Range,
    s: Range,

    const Range = struct {
        min: usize,
        max: usize,
        fn splitAt(self: Range, number: usize) [2]?Range {
            return .{
                if (self.min <= number)
                    .{
                        .min = self.min,
                        .max = @min(number, self.max),
                    }
                else
                    null,
                if (self.max > number)
                    .{
                        .min = @max(self.min, number + 1),
                        .max = self.max,
                    }
                else
                    null,
            };
        }
        fn length(self: Range) usize {
            std.debug.assert(self.max >= self.min);
            return self.max - self.min + 1;
        }
    };
};

test "splitAt" {
    const range: Part.Range = .{
        .min = 1,
        .max = 4000,
    };
    const numbers: []const usize = &.{ 0, 1, 2000, 4000, 4001 };
    const outputs: []const [2]?Part.Range = &.{
        .{ null, .{ .min = 1, .max = 4000 } },
        .{ .{ .min = 1, .max = 1 }, .{ .min = 2, .max = 4000 } },
        .{ .{ .min = 1, .max = 2000 }, .{ .min = 2001, .max = 4000 } },
        .{ .{ .min = 1, .max = 4000 }, null },
        .{ .{ .min = 1, .max = 4000 }, null },
    };
    for (numbers, outputs) |number, expected| {
        try std.testing.expectEqualDeep(expected, range.splitAt(number));
    }
}

const Map = std.StringArrayHashMap(Queue);

const Queue = struct {
    directions: []const u8,
    head: ?*Node = null,
    tail: ?*Node = null,
    size: usize = 0,

    const Node = struct {
        part: Part,
        next: ?*Node = null,
    };

    fn addToTail(self: *Queue, node: *Node) void {
        if (self.tail) |tail| {
            tail.next = node;
        } else self.head = node;
        self.tail = node;
        self.size += 1;
    }
    fn removeFromHead(self: *Queue) ?*Node {
        if (self.head) |node| {
            self.head = node.next;
            self.size -= 1;
            if (self.size == 0) self.tail = null;
            return node;
        } else return null;
    }
};

fn addToMap(line: []const u8, map: *Map) !void {
    var tokenizer = std.mem.tokenizeAny(u8, line, "{}");
    const key = tokenizer.next() orelse return error.ParseFailed;
    const val = tokenizer.next() orelse return error.ParseFailed;
    const queue: Queue = .{
        .directions = val,
    };
    try map.put(key, queue);
}

test "end-to-end" {
    const input =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;
    const keys: []const []const u8 = &.{
        "px", "pv", "lnx", "rfg", "qs", "qkq", "crn", "in", "qqz", "gd", "hdj",
    };
    const vals: []const []const u8 = &.{
        "a<2006:qkq,m>2090:A,rfg",
        "a>1716:R,A",
        "m>1548:A,A",
        "s<537:gd,x>2440:R,A",
        "s>3448:A,lnx",
        "x<1416:A,crn",
        "x>2662:A,R",
        "s<1351:px,qqz",
        "s>2770:qs,m<1801:hdj,R",
        "a>3333:R,R",
        "m>838:A,pv",
    };
    var map = Map.init(std.testing.allocator);
    defer map.deinit();
    var tokenizer = std.mem.splitScalar(u8, input, '\n');
    while (tokenizer.next()) |token| {
        if (token.len == 0) break;
        try addToMap(token, &map);
    }
    for (keys, vals) |key, val| {
        const got = map.get(key) orelse return error.TestFailed;
        try std.testing.expectEqualStrings(val, got.directions);
        try std.testing.expectEqual(@as(usize, 0), got.size);
    }
    const queue = map.getPtr("in") orelse return error.TestFailed;
    const node = try std.testing.allocator.create(Queue.Node);
    node.* = .{ .part = .{
        .x = .{ .min = 1, .max = 4000 },
        .m = .{ .min = 1, .max = 4000 },
        .a = .{ .min = 1, .max = 4000 },
        .s = .{ .min = 1, .max = 4000 },
    } };
    queue.addToTail(node);
    var count: usize = 0;
    while (!(try stepThrough(&map, &count, std.testing.allocator))) {}
    try std.testing.expectEqual(@as(usize, 167409079868000), count);
}

fn stepThrough(map: *Map, count: *usize, allocator: std.mem.Allocator) !bool {
    const keys = map.keys();
    var done = true;
    var temp: Queue = .{
        .directions = undefined,
    };
    for (keys) |key| {
        const queue = map.getPtr(key).?;
        if (queue.size == 0) continue;
        done = false;
        var tokenizer = std.mem.tokenizeScalar(u8, queue.directions, ',');
        while (tokenizer.next()) |direction| {
            while (queue.removeFromHead()) |node| {
                if (std.mem.indexOfScalar(u8, direction, ':')) |idx| {
                    const number = try std.fmt.parseUnsigned(usize, direction[2..idx], 10);
                    switch (direction[0]) {
                        'x' => {
                            switch (direction[1]) {
                                '>' => {
                                    const outcome = node.part.x.splitAt(number);
                                    if (outcome[0]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .x = failed,
                                            .m = node.part.m,
                                            .a = node.part.a,
                                            .s = node.part.s,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[1]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.m.length() * node.part.a.length() * node.part.s.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .x = succeeded,
                                                    .m = node.part.m,
                                                    .a = node.part.a,
                                                    .s = node.part.s,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                '<' => {
                                    const outcome = node.part.x.splitAt(number - 1);
                                    if (outcome[1]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .x = failed,
                                            .m = node.part.m,
                                            .a = node.part.a,
                                            .s = node.part.s,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[0]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.m.length() * node.part.a.length() * node.part.s.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .x = succeeded,
                                                    .m = node.part.m,
                                                    .a = node.part.a,
                                                    .s = node.part.s,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                else => return error.ParseFailed,
                            }
                        },
                        'm' => {
                            switch (direction[1]) {
                                '>' => {
                                    const outcome = node.part.m.splitAt(number);
                                    if (outcome[0]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .m = failed,
                                            .x = node.part.x,
                                            .a = node.part.a,
                                            .s = node.part.s,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[1]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.x.length() * node.part.a.length() * node.part.s.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .m = succeeded,
                                                    .x = node.part.x,
                                                    .a = node.part.a,
                                                    .s = node.part.s,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                '<' => {
                                    const outcome = node.part.m.splitAt(number - 1);
                                    if (outcome[1]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .m = failed,
                                            .x = node.part.x,
                                            .a = node.part.a,
                                            .s = node.part.s,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[0]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.x.length() * node.part.a.length() * node.part.s.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .m = succeeded,
                                                    .x = node.part.x,
                                                    .a = node.part.a,
                                                    .s = node.part.s,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                else => return error.ParseFailed,
                            }
                        },
                        'a' => {
                            switch (direction[1]) {
                                '>' => {
                                    const outcome = node.part.a.splitAt(number);
                                    if (outcome[0]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .a = failed,
                                            .m = node.part.m,
                                            .x = node.part.x,
                                            .s = node.part.s,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[1]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.m.length() * node.part.x.length() * node.part.s.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .a = succeeded,
                                                    .m = node.part.m,
                                                    .x = node.part.x,
                                                    .s = node.part.s,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                '<' => {
                                    const outcome = node.part.a.splitAt(number - 1);
                                    if (outcome[1]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .a = failed,
                                            .m = node.part.m,
                                            .x = node.part.x,
                                            .s = node.part.s,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[0]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.m.length() * node.part.x.length() * node.part.s.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .a = succeeded,
                                                    .m = node.part.m,
                                                    .x = node.part.x,
                                                    .s = node.part.s,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                else => return error.ParseFailed,
                            }
                        },
                        's' => {
                            switch (direction[1]) {
                                '>' => {
                                    const outcome = node.part.s.splitAt(number);
                                    if (outcome[0]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .s = failed,
                                            .m = node.part.m,
                                            .a = node.part.a,
                                            .x = node.part.x,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[1]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.m.length() * node.part.a.length() * node.part.x.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .s = succeeded,
                                                    .m = node.part.m,
                                                    .a = node.part.a,
                                                    .x = node.part.x,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                '<' => {
                                    const outcome = node.part.s.splitAt(number - 1);
                                    if (outcome[1]) |failed| {
                                        const new = try allocator.create(Queue.Node);
                                        new.* = .{ .part = .{
                                            .s = failed,
                                            .m = node.part.m,
                                            .a = node.part.a,
                                            .x = node.part.x,
                                        } };
                                        temp.addToTail(new);
                                    }
                                    if (outcome[0]) |succeeded| {
                                        const new_key = direction[idx + 1 ..];
                                        switch (new_key[0]) {
                                            'A' => count.* += succeeded.length() * node.part.m.length() * node.part.a.length() * node.part.x.length(),
                                            'R' => {},
                                            else => {
                                                const new = try allocator.create(Queue.Node);
                                                new.* = .{ .part = .{
                                                    .s = succeeded,
                                                    .m = node.part.m,
                                                    .a = node.part.a,
                                                    .x = node.part.x,
                                                } };
                                                const next_queue = map.getPtr(new_key) orelse return error.ParseFailed;
                                                next_queue.addToTail(new);
                                            },
                                        }
                                    }
                                    allocator.destroy(node);
                                },
                                else => return error.ParseFailed,
                            }
                        },
                        else => return error.ParseFailed,
                    }
                } else {
                    switch (direction[0]) {
                        'A' => {
                            count.* += node.part.x.length() * node.part.m.length() * node.part.a.length() * node.part.s.length();
                            allocator.destroy(node);
                        },
                        'R' => allocator.destroy(node),
                        else => {
                            const next_queue = map.getPtr(direction) orelse return error.ParseFailed;
                            next_queue.addToTail(node);
                        },
                    }
                }
            }

            while (temp.removeFromHead()) |n| {
                queue.addToTail(n);
            }
        }
    }
    return done;
}
