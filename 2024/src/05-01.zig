const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("05.txt", .{});
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
    try stdout.print("elasped time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(gpa: std.mem.Allocator, input: []const u8) !u32 {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const split = std.mem.indexOf(u8, input, "\n\n") orelse return error.BadInput;

    var count: u32 = 0;
    const rules = try buildRules(allocator, input[0..split]);
    var list: std.ArrayListUnmanaged(u32) = .{};
    defer list.deinit(allocator);
    var iter = std.mem.tokenizeScalar(u8, input[split + 2 ..], '\n');
    while (iter.next()) |line| {
        list.clearRetainingCapacity();
        var tokenizer = std.mem.splitScalar(u8, line, ',');
        while (tokenizer.next()) |token| {
            const new = try std.fmt.parseInt(u32, token, 10);
            const rule = rules.get(new) orelse {
                try list.append(allocator, new);
                continue;
            };
            if (std.mem.indexOfAny(u32, rule, list.items)) |_| break;
            try list.append(allocator, new);
        } else {
            // the length must be odd. the middle index (starting from 1) is (len + 1) / 2, but we're 0-indexing
            const middle_idx = @divExact(list.items.len - 1, 2);
            count += list.items[middle_idx];
        }
    }
    return count;
}

fn buildRules(arena: std.mem.Allocator, rules: []const u8) !std.AutoHashMapUnmanaged(u32, []u32) {
    var left_list: std.ArrayListUnmanaged(u32) = .{};
    var right_list: std.ArrayListUnmanaged(u32) = .{};
    var count_map: std.AutoArrayHashMapUnmanaged(u32, usize) = .{};
    defer left_list.deinit(arena);
    defer right_list.deinit(arena);
    defer count_map.deinit(arena);
    var iter = std.mem.tokenizeScalar(u8, rules, '\n');
    while (iter.next()) |rule| {
        const left, const right = parse: {
            const pipe = std.mem.indexOfScalar(u8, rule, '|') orelse return error.BadInput;
            const left = try std.fmt.parseInt(u32, rule[0..pipe], 10);
            const right = try std.fmt.parseInt(u32, rule[pipe + 1 ..], 10);
            break :parse .{ left, right };
        };
        try left_list.append(arena, left);
        try right_list.append(arena, right);
        const res = try count_map.getOrPut(arena, left);
        if (res.found_existing) res.value_ptr.* += 1 else res.value_ptr.* = 1;
    }
    var map: std.AutoHashMapUnmanaged(u32, []u32) = .{};
    try map.ensureTotalCapacity(arena, @intCast(count_map.count()));
    for (count_map.keys()) |key| {
        const ptr = count_map.getPtr(key).?;
        const slice = try arena.alloc(u32, ptr.*);
        ptr.* = 0;
        map.putAssumeCapacity(key, slice);
    }
    for (left_list.items, right_list.items) |left, right| {
        const idx = count_map.getPtr(left).?;
        const slice = map.get(left).?;
        slice[idx.*] = right;
        idx.* += 1;
    }
    return map;
}

test {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(143, output);
}
