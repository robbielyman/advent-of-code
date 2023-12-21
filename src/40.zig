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

    var map = Map.init(allocator);
    defer destroy(&map, allocator);
    {
        var tokenizer = std.mem.tokenizeScalar(u8, contents, '\n');
        while (tokenizer.next()) |line| try addToMap(line, &map, allocator);
        try map.put("rx", .{
            .children = try allocator.alloc([]const u8, 0),
            .parents = undefined,
            .kind = null,
            .last = .low,
            .state = false,
        });
        try parseParents(&map, allocator);
    }
    var queue = Queue.init(allocator);
    defer queue.deinit();

    const grandparents = ancestors: {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();
        const rx = map.get("rx").?;
        for (rx.parents) |n| {
            const parent = map.get(n).?;
            for (parent.parents) |grandparent| try list.append(grandparent);
        }
        break :ancestors try list.toOwnedSlice();
    };
    defer allocator.free(grandparents);
    const times_out = try allocator.alloc(?usize, grandparents.len);
    defer allocator.free(times_out);
    @memset(times_out, null);

    try pushButton(&map, &queue, grandparents, times_out);
    var count: usize = 1;
    for (times_out) |val| {
        count = lcm(count, val.?); 
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn lcm(a: usize, b: usize) usize {
    for (1..b) |n| {
        const an = a * n;
        if (an % b == 0) return an;
    } else return a * b;
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

const Map = std.StringArrayHashMap(Module);

fn addToMap(line: []const u8, map: *Map, allocator: std.mem.Allocator) !void {
    var tokenizer = std.mem.tokenizeSequence(u8, line, " -> ");
    const name_and_type = tokenizer.next() orelse return error.ParseFailed;
    const children_seq = tokenizer.next() orelse return error.ParseFailed;
    const children = children: {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();
        var parser = std.mem.tokenizeSequence(u8, children_seq, ", ");
        while (parser.next()) |item| {
            try list.append(item);
        }
        break :children try list.toOwnedSlice();
    };
    const name, const kind: ?Kind = blk: {
        if (name_and_type[0] == '&' or name_and_type[0] == '%') {
            break :blk .{
                name_and_type[1..],
                if (name_and_type[0] == '%') .flip_flop else .conjunction,
            };
        } else break :blk .{ name_and_type, null };
    };
    const module: Module = .{
        .children = children,
        .parents = undefined,
        .kind = kind,
        .last = .low,
        .state = false,
    };
    try map.put(name, module);
}

fn parseParents(map: *Map, allocator: std.mem.Allocator) !void {
    for (map.keys()) |name| {
        var list = std.ArrayList([]const u8).init(allocator);
        errdefer list.deinit();
        for (map.keys()) |parent_name| {
            const parent = map.get(parent_name).?;
            for (parent.children) |child_name| {
                if (std.mem.eql(u8, child_name, name)) try list.append(parent_name);
            }
        }
        const module = map.getPtr(name).?;
        module.parents = try list.toOwnedSlice();
    }
}

fn destroy(map: *Map, allocator: std.mem.Allocator) void {
    for (map.values()) |module| {
        allocator.free(module.children);
        allocator.free(module.parents);
    }
    map.deinit();
}

const Pulse = enum { high, low };
const Kind = enum { flip_flop, conjunction };

const Module = struct {
    children: []const []const u8,
    parents: []const []const u8,
    kind: ?Kind,
    last: Pulse,
    state: bool,
};

test "build map" {
    const input =
        \\broadcaster -> a, b, c
        \\%a -> b
        \\%b -> c
        \\%c -> inv
        \\&inv -> a
    ;
    const keys: []const []const u8 = &.{ "broadcaster", "a", "b", "c", "inv" };
    const children_list: []const []const []const u8 = &.{
        &.{ "a", "b", "c" },
        &.{"b"},
        &.{"c"},
        &.{"inv"},
        &.{"a"},
    };
    const parents_list: []const []const []const u8 = &.{
        &.{},
        &.{ "broadcaster", "inv" },
        &.{ "broadcaster", "a" },
        &.{ "broadcaster", "b" },
        &.{"c"},
    };
    const allocator = std.testing.allocator;
    var map = Map.init(allocator);
    defer destroy(&map, allocator);
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        try addToMap(line, &map, allocator);
    }
    try parseParents(&map, allocator);
    for (keys, children_list, parents_list) |key, children, parents| {
        const module = map.get(key) orelse return error.TestFailed;
        try std.testing.expectEqual(children.len, module.children.len);
        for (children) |child| {
            for (module.children) |value| {
                if (std.mem.eql(u8, child, value)) break;
            } else return error.TestFailed;
        }
        try std.testing.expectEqual(parents.len, module.parents.len);
        for (parents) |parent| {
            for (module.parents) |value| {
                if (std.mem.eql(u8, parent, value)) break;
            } else return error.TestFailed;
        }
    }
}

const Queue = std.fifo.LinearFifo(Event, .{ .Dynamic = {} });

const Event = struct {
    name: []const u8,
    pulse: Pulse,
};

fn processPulse(module: *Module, pulse: Pulse, map: *Map, queue: *Queue) !void {
    if (module.kind) |kind| {
        switch (kind) {
            .conjunction => {
                const new_pulse: Pulse = new: {
                    for (module.parents) |name| {
                        const parent = map.get(name) orelse return error.ParentNotFound;
                        if (parent.last == .low) break :new .high;
                    } else break :new .low;
                };
                module.last = new_pulse;
                for (module.children) |name| {
                    try queue.writeItem(.{ .name = name, .pulse = new_pulse });
                }
            },
            .flip_flop => {
                if (pulse == .high) return;
                const new_pulse: Pulse = if (module.state) .low else .high;
                module.state = !module.state;
                module.last = new_pulse;
                for (module.children) |name| {
                    try queue.writeItem(.{
                        .name = name,
                        .pulse = new_pulse,
                    });
                }
            },
        }
    } else {
        module.last = pulse;
        for (module.children) |name| {
            try queue.writeItem(.{
                .name = name,
                .pulse = pulse,
            });
        }
    }
}

fn pushButton(map: *Map, queue: *Queue, names: []const []const u8, times_out: []?usize) !void {
    var count: usize = 0;
    var done = false;
    while (!done) {
        count += 1;
        try queue.writeItem(.{
            .name = "broadcaster",
            .pulse = .low,
        });
        while (queue.readItem()) |event| {
            const module = map.getPtr(event.name) orelse return error.ModuleNotFound;
            for (names, times_out) |name, *time| {
                if (time.* == null and std.mem.eql(u8, event.name, name) and event.pulse == .low) {
                    time.* = count;
                }
            }
            try processPulse(module, event.pulse, map, queue);
        }
        if (std.mem.indexOfScalar(?usize, times_out, null) == null) done = true; 
    }
}
