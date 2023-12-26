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
    
    var count: usize = 0;
    while (count == 0) {
        var vertex_set = VertexSet.init(allocator);
        defer vertex_set.deinit();
        var edge_set = EdgeSet.init(allocator);
        defer edge_set.deinit();

        try buildGraph(contents, &vertex_set, &edge_set);
        count = findThreeEdgeCut(&vertex_set, &edge_set) catch |err| switch (err) {
            error.TryAgain => 0,
            else => return err,
        };
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{
        @divTrunc(timer.read(), std.time.ns_per_ms),
    });
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
    const filename = args.next() orelse return error.NoFilename;
    return try allocator.dupe(u8, filename);
}

test "buildGraph" {
    const input =
        \\jqt: rhn xhk nvd
        \\rsh: frs pzl lsr
        \\xhk: hfx
        \\cmg: qnr nvd lhk bvb
        \\rhn: xhk bvb hfx
        \\bvb: xhk hfx
        \\pzl: lsr hfx nvd
        \\qnr: nvd
        \\ntq: jqt hfx bvb xhk
        \\nvd: lhk
        \\lsr: lhk
        \\rzs: qnr cmg lsr rsh
        \\frs: qnr lhk lsr
    ;
    const allocator = std.testing.allocator;
    var vertex_set = VertexSet.init(allocator);
    defer vertex_set.deinit();
    var edge_set = EdgeSet.init(allocator);
    defer edge_set.deinit();
    try buildGraph(input, &vertex_set, &edge_set);
    try std.testing.expectEqual(@as(usize, 15), vertex_set.keys().len);
    try std.testing.expectEqual(@as(usize, 33), edge_set.keys().len);
}

const VertexSet = std.StringArrayHashMap(usize);
const EdgeSet = std.ArrayHashMap([2][]const u8, void, Context, true);

const Context = struct {
    pub fn hash(ctx: Context, k: [2][]const u8) u32 {
        _ = ctx;
        return std.hash.Murmur2_32.hash(k[0]) +% std.hash.Murmur2_32.hash(k[1]);
    }

    pub fn eql(ctx: Context, a: [2][]const u8, b: [2][]const u8, b_index: usize) bool {
        _ = b_index;

        _ = ctx;
        if (std.mem.eql(u8, a[0], b[0]) and std.mem.eql(u8, a[1], b[1])) return true;
        if (std.mem.eql(u8, a[1], b[0]) and std.mem.eql(u8, a[0], b[1])) return true;
        return false;
    }
};

fn buildGraph(input: []const u8, vertex_set: *VertexSet, edge_set: *EdgeSet) !void {
    var idx: usize = 0;

    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (tokenizer.next()) |line| {
        const delim = std.mem.indexOfScalar(u8, line, ':') orelse return error.ParseFailed;
        const a = line[0..delim];
        const res = try vertex_set.getOrPut(a);
        if (!res.found_existing) {
            res.value_ptr.* = idx;
            idx += 1;
        }
        var splitter = std.mem.tokenizeScalar(u8, line[delim + 1 ..], ' ');
        while (splitter.next()) |b| {
            const bres = try vertex_set.getOrPut(b);
            if (!bres.found_existing) {
                bres.value_ptr.* = idx;
                idx += 1;
            }
            try edge_set.put(.{ a, b }, {});
        }
    }
}

fn findThreeEdgeCut(vertex_set: *VertexSet, edge_set: *EdgeSet) !usize {
    var seed = std.rand.DefaultPrng.init(@truncate(@abs(std.time.nanoTimestamp())));
    const random = seed.random();
    var num_verts = vertex_set.keys().len;

    while (num_verts > 2) : (num_verts -= 1) {
        const i, const j = findedge: {
            while (true) {
                const randedge = random.uintLessThan(usize, edge_set.keys().len);
                const edge = edge_set.keys()[randedge];
                const i = vertex_set.get(edge[0]).?;
                const j = vertex_set.get(edge[1]).?;
                if (i < j) break :findedge .{ i, j };
                if (i > j) break :findedge .{ j, i };
            }
        };
        for (vertex_set.keys()) |key| {
            const val = vertex_set.getPtr(key).?;
            if (val.* == j) val.* = i;
        }
    }
    var count: usize = 0;
    for (edge_set.keys()) |key| {
        const i = vertex_set.get(key[0]).?;
        const j = vertex_set.get(key[1]).?;
        if (i != j) count += 1;
    }
    if (count != 3) return error.TryAgain;
    var a: usize = 0;
    var b: usize = 0;
    for (vertex_set.values()) |val| {
        if (vertex_set.values()[0] == val) a += 1 else b += 1;
    }
    return a * b;
}

test "findThreeEdgeCut" {
    const input =
        \\jqt: rhn xhk nvd
        \\rsh: frs pzl lsr
        \\xhk: hfx
        \\cmg: qnr nvd lhk bvb
        \\rhn: xhk bvb hfx
        \\bvb: xhk hfx
        \\pzl: lsr hfx nvd
        \\qnr: nvd
        \\ntq: jqt hfx bvb xhk
        \\nvd: lhk
        \\lsr: lhk
        \\rzs: qnr cmg lsr rsh
        \\frs: qnr lhk lsr
    ;
    const allocator = std.testing.allocator;
    
    var count: usize = 0;
    while (count == 0) {
        var vertex_set = VertexSet.init(allocator);
        defer vertex_set.deinit();
        var edge_set = EdgeSet.init(allocator);
        defer edge_set.deinit();

        try buildGraph(input, &vertex_set, &edge_set);
    
        count = findThreeEdgeCut(&vertex_set, &edge_set) catch |err| blk: {
            if (err == error.TryAgain) break :blk 0 else return err;
        };
    }
    try std.testing.expectEqual(@as(usize, 54), count);
}
