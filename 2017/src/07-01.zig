const std = @import("std");

const Children = struct {
    list: std.ArrayListUnmanaged([]const u8),
    parent: ?[]const u8,
    weight: Weight,

    fn deinit(self: *Children, allocator: std.mem.Allocator) void {
        self.list.deinit(allocator);
        self.* = undefined;
    }

    const Weight = enum(u32) {
        uninit = std.math.maxInt(u32),
        _,

        fn init(w: u32) Weight {
            std.debug.assert(w != @intFromEnum(Weight.uninit));
            return @enumFromInt(w);
        }

        fn num(self: Weight) u32 {
            std.debug.assert(self != .uninit);
            return @intFromEnum(self);
        }
    };

    const empty: Children = .{
        .list = .empty,
        .parent = null,
        .weight = .uninit,
    };
};

const Nodes = std.StringArrayHashMapUnmanaged(Children);

pub fn process(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var nodes: Nodes = .empty;
    defer {
        for (nodes.values()) |*val| val.deinit(allocator);
        nodes.deinit(allocator);
    }
    var it = std.mem.tokenizeScalar(u8, input, '\n');
    while (it.next()) |line| {
        const space = std.mem.indexOfScalar(u8, line, ' ').?;
        const key = line[0..space];
        const gop = try nodes.getOrPut(allocator, key);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        const weight = weight: {
            const left = std.mem.indexOfScalar(u8, line, '(').?;
            const right = std.mem.indexOfScalar(u8, line, ')').?;
            break :weight line[left + 1 .. right];
        };
        gop.value_ptr.weight = .init(try std.fmt.parseInt(u32, weight, 10));
        const needle = " -> ";
        if (std.mem.indexOf(u8, line, needle)) |idx| {
            var inner = std.mem.tokenizeSequence(u8, line[idx + needle.len ..], ", ");
            var list: std.ArrayListUnmanaged([]const u8) = .empty;
            while (inner.next()) |child| try list.append(allocator, child);
            gop.value_ptr.list = list;
            for (list.items) |child_key| {
                const child = try nodes.getOrPut(allocator, child_key);
                if (!child.found_existing) child.value_ptr.* = .empty;
                child.value_ptr.parent = key;
            }
        }
    }
    for (nodes.keys(), nodes.values()) |key, val| {
        if (val.parent == null) return key;
    }
    unreachable;
}

test process {
    const input =
        \\pbga (66)
        \\xhth (57)
        \\ebii (61)
        \\havc (66)
        \\ktlj (57)
        \\fwft (72) -> ktlj, cntj, xhth
        \\qoyq (66)
        \\padx (45) -> pbga, havc, qoyq
        \\tknk (41) -> ugml, padx, fwft
        \\jptl (61)
        \\ugml (68) -> gyxo, ebii, jptl
        \\gyxo (61)
        \\cntj (57)
    ;
    try std.testing.expectEqualStrings(
        "tknk",
        try process(std.testing.allocator, input),
    );
}
