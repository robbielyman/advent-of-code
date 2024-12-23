const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("23.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(allocator, input);
    defer allocator.free(output);
    const vertices: Vertices = .{ .data = output };
    const elapsed = timer.read();

    try stdout.print("{}\n", .{vertices});
    try stdout.print("elapsed time: {}ms\n", .{elapsed / std.time.ns_per_ms});
    try bw.flush();
}

const Vertices = struct {
    data: []const Vertex,
    pub fn format(self: Vertices, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        for (self.data, 0..) |vertex, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{}", .{vertex});
        }
    }
};

const Vertex = packed struct {
    a: u8,
    b: u8,

    pub fn format(self: Vertex, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeByte(self.a);
        try writer.writeByte(self.b);
    }
};

fn process(allocator: std.mem.Allocator, input: []const u8) ![]const Vertex {
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    var edge_list: std.AutoHashMapUnmanaged([2][2]u8, void) = .{};
    defer edge_list.deinit(allocator);
    var vertices: std.AutoArrayHashMapUnmanaged([2]u8, void) = .{};
    defer vertices.deinit(allocator);
    var triangles: std.AutoArrayHashMapUnmanaged([3][2]u8, void) = .{};
    defer triangles.deinit(allocator);

    while (iterator.next()) |line| {
        if (!(line[2] == '-') or line.len != 5) return error.BadInput;
        const a = line[0..2].*;
        const b = line[3..5].*;
        try edge_list.put(allocator, .{ a, b }, {});
        try edge_list.put(allocator, .{ b, a }, {});
        const a_res = try vertices.getOrPut(allocator, a);
        const b_res = try vertices.getOrPut(allocator, b);
        // a triangle can only be found if neither of the vertices of its last edge are new
        if (!a_res.found_existing or !b_res.found_existing) continue;
        for (vertices.keys()) |c| {
            if (@as(u16, @bitCast(c)) == @as(u16, @bitCast(a)) or @as(u16, @bitCast(c)) == @as(u16, @bitCast(b))) continue;
            if (!edge_list.contains(.{ a, c }) or !edge_list.contains(.{ b, c })) continue;
            var triangle: [3][2]u8 = .{ a, b, c };
            std.mem.sort([2]u8, &triangle, {}, lessThan);
            try triangles.put(allocator, triangle, {});
        }
    }
    var biggest_clique: ?[]align(2) [2]u8 = null;
    var candidate_vertices: std.AutoArrayHashMapUnmanaged([2]u8, void) = .{};
    defer candidate_vertices.deinit(allocator);

    for (triangles.keys()) |seed_triangle| {
        candidate_vertices.clearRetainingCapacity();
        for (seed_triangle) |vertex| try candidate_vertices.put(allocator, vertex, {});
        for (vertices.keys()) |v| {
            if (candidate_vertices.contains(v)) continue;
            const keys = candidate_vertices.keys();
            for (keys, 0..) |u, i| {
                for (keys[i + 1 ..]) |w| {
                    var triangle: [3][2]u8 = .{ u, v, w };
                    std.mem.sort([2]u8, &triangle, {}, lessThan);
                    if (!triangles.contains(triangle)) break;
                } else continue;
                break;
            } else try candidate_vertices.put(allocator, v, {});
        }
        if (biggest_clique) |big_clique|
            if (candidate_vertices.count() <= big_clique.len) continue else allocator.free(big_clique);
        const slice = try allocator.alignedAlloc([2]u8, 2, candidate_vertices.count());
        @memcpy(slice, candidate_vertices.keys());
        biggest_clique = slice;
    }
    std.mem.sort([2]u8, biggest_clique orelse return error.Failed, {}, lessThan);
    return @ptrCast(biggest_clique.?);
}

fn lessThan(_: void, a: [2]u8, b: [2]u8) bool {
    if (a[0] < b[0]) return true;
    if (a[0] == b[0] and a[1] < b[1]) return true;
    return false;
}

test {
    const input =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;
    const output = try process(std.testing.allocator, input);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualSlices([2]u8, &.{ "co".*, "de".*, "ka".*, "ta".* }, @ptrCast(output));
}
