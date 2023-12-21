const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const contents = contents: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :contents try getContents(filename, allocator);
    };
    defer allocator.free(contents);

    const map, const start = map: {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();
        var coord: [2]?usize = .{ null, null };
        var tokenizer = std.mem.tokenizeScalar(u8, contents, '\n');
        var y: usize = 0;
        while (tokenizer.next()) |line| : (y += 1) {
            try list.append(line);
            for (line, 0..) |char, x| {
                if (char == 'S') coord = .{ x, y };
            }
        }
        break :map .{ try list.toOwnedSlice(), .{ coord[0].?, coord[1].? } };
    };
    defer allocator.free(map);

    var queue = Queue.init(allocator);
    errdefer queue.deinit();

    try queue.writeItem(.{
        .x = start[0],
        .y = start[1],
        .number = 0,
    });
    try takeSteps(&queue, 64, map);
    const spots = try queue.toOwnedSlice();
    defer allocator.free(spots);
    var count: usize = 0;
    for (spots, 0..) |step, i| {
        if (step.number == 64) {
            const add = add: {
                for (spots[0..i]) |other| {
                    if (other.number == 64 and other.x == step.x and other.y == step.y) break :add false;
                } else break :add true;
            };
            if (add) count += 1;
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{ @divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn getContents(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
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

const Queue = struct {
    allocator: std.mem.Allocator,
    head: ?*Node,

    const Node = struct {
        next: ?*Node,
        data: Step,
    };

    fn init(allocator: std.mem.Allocator) Queue {
        return .{
            .allocator = allocator,
            .head = null,
        };
    }

    fn writeItem(self: *Queue, item: Step) !void {
        var curr: ?*Node  = null;
        var next = self.head;
        while (next) |node| {
            curr = node;
            if (node.data.eql(item)) return;
            next = node.next;
        }
        const node = try self.allocator.create(Node);
        node.* = .{
            .data = item,
            .next = null,
        };
        if (curr) |tail| {
            tail.next = node;
        } else self.head = node;
    }

    fn readItem(self: *Queue) ?Step {
        if (self.head) |node| {
            self.head = node.next;
            defer self.allocator.destroy(node);
            return node.data;
        } else return null;
    }

    fn ungetItem(self: *Queue, item: Step) !void {
        const node = try self.allocator.create(Node);
        node.* = .{
            .data = item,
            .next = self.head,
        };
        self.head = node;
    }

    fn toOwnedSlice(self: *Queue) ![]Step {
        var list = std.ArrayList(Step).init(self.allocator);
        errdefer list.deinit();
        var curr = self.head;
        while (curr) |node| {
            defer self.allocator.destroy(node);
            curr = node.next;
            try list.append(node.data);
        }
        return try list.toOwnedSlice();
    }

    fn deinit(self: *Queue) void {
        var curr = self.head;
        while (curr) |node| {
            curr = node.next;
            self.allocator.destroy(node);
        }
        self.* = undefined;
    }
};

const Step = struct {
    x: usize,
    y: usize,
    number: usize,

    fn eql(a: Step, b: Step) bool {
        return a.x == b.x and a.y == b.y and a.number == b.number;
    }
};

test "end to end" {
    const input =
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
    ;
    const allocator = std.testing.allocator;
    const lines: []const []const u8, const start = lines: {
        var list = std.ArrayList([]const u8).init(allocator);
        var coord: [2]?usize = .{ null, null };
        errdefer list.deinit();
        var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
        var y: usize = 0;
        while (tokenizer.next()) |line| : (y += 1) {
            try list.append(line);
            for (line, 0..) |char, x| {
                if (char == 'S') coord = .{ x, y };
            }
        }
        break :lines .{ try list.toOwnedSlice(), .{ coord[0].?, coord[1].? } };
    };
    defer allocator.free(lines);
    var queue = Queue.init(allocator);
    try queue.writeItem(.{
        .x = start[0], .y = start[1], .number = 0
    });
    try takeSteps(&queue, 6, lines);
    const spots = try queue.toOwnedSlice();
    defer allocator.free(spots);
    var count: usize = 0;
    for (spots, 0..) |step, i| {
        if (step.number == 6) {
            const add = add: {
                for (spots[0..i]) |other| {
                    if (other.number == 6 and other.x == step.x and other.y == step.y) break :add false;
                } else break :add true;
            };
            if (add) count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 16), count);
}

fn takeSteps(queue: *Queue, number: usize, map: []const []const u8) !void {
    while (queue.readItem()) |step| {
        if (step.number < number) {
            try takeStep(queue, map, step);
        } else {
            try queue.ungetItem(step);
            return;
        }
    }
}

fn takeStep(queue: *Queue, map: []const []const u8, step: Step) !void {
    const next_steps: [4]?Step = .{
        if (step.y > 0) .{ .x = step.x, .y = step.y - 1, .number = step.number + 1 } else null,
        if (step.y < map.len - 1) .{ .x = step.x, .y = step.y + 1, .number = step.number + 1 } else null,
        if (step.x > 0) .{ .x = step.x - 1, .y = step.y, .number = step.number + 1 } else null,
        if (step.x < map[step.y].len - 1) .{ .x = step.x + 1, .y = step.y, .number = step.number + 1} else null,
    };
    for (next_steps) |n| {
        if (n) |next| {
            if (map[next.y][next.x] != '#') try queue.writeItem(next);
        }
    }
}
