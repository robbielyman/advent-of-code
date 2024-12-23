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
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    var edge_list: std.AutoHashMapUnmanaged([2][2]u8, void) = .{};
    defer edge_list.deinit(allocator);
    var vertices: std.AutoArrayHashMapUnmanaged([2]u8, void) = .{};
    defer vertices.deinit(allocator);
    var t_triangles: std.AutoHashMapUnmanaged([3][2]u8, void) = .{};
    defer t_triangles.deinit(allocator);

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
            const t_present = a[0] == 't' or b[0] == 't' or c[0] == 't';
            if (!t_present) continue;
            if (@as(u16, @bitCast(c)) == @as(u16, @bitCast(a)) or @as(u16, @bitCast(c)) == @as(u16, @bitCast(b))) continue;
            if (!edge_list.contains(.{ a, c }) or !edge_list.contains(.{ b, c })) continue;
            var triangle: [3][2]u8 = .{ a, b, c };
            std.mem.sort([2]u8, &triangle, {}, lessThan);
            try t_triangles.put(allocator, triangle, {});
        }
    }
    return t_triangles.count();
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
    try std.testing.expectEqual(7, output);
}
