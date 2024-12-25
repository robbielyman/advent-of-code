const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("24.txt", .{});
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

const Gate = struct {
    payload: [2][3]u8,
    which: Which,

    fn eql(a: Gate, b: Gate) bool {
        if (a.which != b.which) return false;
        if (std.mem.eql(u8, &a.payload[0], &b.payload[0]) and std.mem.eql(u8, &a.payload[1], &b.payload[1])) return true;
        if (std.mem.eql(u8, &a.payload[1], &b.payload[0]) and std.mem.eql(u8, &a.payload[0], &b.payload[1])) return true;
        return false;
    }

    const Which = enum(u2) { @"and", xor, @"or" };

    fn matchIterator(gate: Gate, slice: []const Gate) Iterator {
        return .{
            .gate = gate,
            .slice = slice,
            .idx = 0,
        };
    }

    const Iterator = struct {
        gate: Gate,
        slice: []const Gate,
        idx: usize,

        fn next(iterator: *Iterator) ?usize {
            if (iterator.idx >= iterator.slice.len) return null;
            defer iterator.idx += 1;
            while (iterator.idx < iterator.slice.len) : (iterator.idx += 1) if (iterator.gate.eql(iterator.slice[iterator.idx]))
                return iterator.idx;
            return null;
        }
    };
};

const Value = enum {
    on,
    off,
    not_yet_known,

    pub fn format(value: Value, _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeByte(switch (value) {
            .on => '1',
            .off => '0',
            .not_yet_known => '-',
        });
    }
};

const ValueSlice = struct {
    data: []const Value,

    pub fn format(value: ValueSlice, _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll("0b");
        for (value.data) |val| try writer.print("{}", .{val});
    }
};

fn parseValue(slice: []const Value) error{NotYetKnown}!u64 {
    var out: u64 = 0;
    for (slice, 0..) |val, i| out += switch (val) {
        .on => @as(u64, 1) << @intCast(i),
        .off => 0,
        .not_yet_known => return error.NotYetKnown,
    };
    return out;
}

const Swaps = struct {
    data: [8][3]u8,

    pub fn format(swaps: Swaps, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        for (&swaps.data, 0..) |item, i| {
            if (i > 0) try writer.writeByte(',');
            try writer.print("{s}", .{&item});
        }
    }
};

const Circuit = struct {
    wires: std.AutoArrayHashMapUnmanaged([3]u8, Value) = .{},
    gates: []const Gate,
    out_wires: [][3]u8,

    fn from(allocator: std.mem.Allocator, input: []const u8) !Circuit {
        var wires: std.AutoArrayHashMapUnmanaged([3]u8, Value) = .{};
        errdefer wires.deinit(allocator);
        const split = std.mem.indexOf(u8, input, "\n\n") orelse return error.BadInput;
        {
            var iterator = std.mem.tokenizeScalar(u8, input[0..split], '\n');
            while (iterator.next()) |line| {
                const item = line[0..3].*;
                try wires.put(allocator, item, switch (line[line.len - 1]) {
                    '1' => .on,
                    '0' => .off,
                    else => return error.BadInput,
                });
            }
        }
        var gates: std.ArrayListUnmanaged(Gate) = .{};
        errdefer gates.deinit(allocator);
        var out_wires: std.ArrayListUnmanaged([3]u8) = .{};
        errdefer out_wires.deinit(allocator);
        {
            var iterator = std.mem.tokenizeScalar(u8, input[split + 2 ..], '\n');
            while (iterator.next()) |line| {
                var gate_wires: [3][3]u8 = undefined;
                const which: Gate.Which = which: {
                    if (std.mem.indexOf(u8, line, "AND")) |_| {
                        gate_wires[0] = line[0..3].*;
                        gate_wires[1] = line[3 + 3 + 2 ..][0..3].*;
                        gate_wires[2] = line[3 + 3 + 3 + 2 + 2 + 2 ..][0..3].*;
                        break :which .@"and";
                    } else if (std.mem.indexOf(u8, line, "XOR")) |_| {
                        gate_wires[0] = line[0..3].*;
                        gate_wires[1] = line[3 + 3 + 2 ..][0..3].*;
                        gate_wires[2] = line[3 + 3 + 3 + 2 + 2 + 2 ..][0..3].*;
                        break :which .xor;
                    } else { // OR gate
                        gate_wires[0] = line[0..3].*;
                        gate_wires[1] = line[3 + 2 + 2 ..][0..3].*;
                        gate_wires[2] = line[3 + 2 + 3 + 2 + 2 + 2 ..][0..3].*;
                        break :which .@"or";
                    }
                };
                try gates.append(allocator, .{ .which = which, .payload = .{ gate_wires[0], gate_wires[1] } });
                try out_wires.append(allocator, gate_wires[2]);
                for (&gate_wires) |wire| {
                    const res = try wires.getOrPut(allocator, wire);
                    if (!res.found_existing) res.value_ptr.* = .not_yet_known;
                }
            }
        }
        return .{
            .wires = wires,
            .gates = try gates.toOwnedSlice(allocator),
            .out_wires = try out_wires.toOwnedSlice(allocator),
        };
    }

    fn testWires(circuit: Circuit, to_test: []const [3]u8, out_buf: []Value) error{ BadInput, NotYetKnown }!void {
        for (to_test, out_buf) |item, *ptr|
            ptr.* = circuit.wires.get(item) orelse return error.BadInput;
    }

    fn reset(circuit: Circuit) void {
        @memset(circuit.wires.values(), .not_yet_known);
    }

    fn set(circuit: Circuit, nodes_to_set: []const [3]u8, value: u64) error{BadInput}!void {
        for (nodes_to_set, 0..) |item, i| {
            const val = circuit.wires.getPtr(item) orelse return error.BadInput;
            val.* = if (value & (@as(u64, 1) << @intCast(i)) != 0) .on else .off;
        }
    }

    fn propagate(circuit: Circuit) enum { changed, unchanged } {
        var counter: usize = 0;
        for (circuit.gates, circuit.out_wires) |gate, wire| {
            const val = circuit.wires.getPtr(wire).?;
            if (val.* != .not_yet_known) continue;
            const a = circuit.wires.get(gate.payload[0]).?;
            if (a == .not_yet_known) continue;
            const b = circuit.wires.get(gate.payload[1]).?;
            if (b == .not_yet_known) continue;
            counter += 1;
            val.* = switch (gate.which) {
                .@"and" => if (a == .on and b == .on) .on else .off,
                .xor => if (a != b) .on else .off,
                .@"or" => if (a == .on or b == .on) .on else .off,
            };
            counter += 1;
        }
        return if (counter > 0) .changed else .unchanged;
    }

    fn run(circuit: Circuit, list_a: []const [3]u8, val_a: u64, list_b: []const [3]u8, val_b: u64) !void {
        circuit.reset();
        try circuit.set(list_a, val_a);
        try circuit.set(list_b, val_b);
        while (circuit.propagate() != .unchanged) {}
    }

    fn deinit(circuit: *Circuit, allocator: std.mem.Allocator) void {
        allocator.free(circuit.gates);
        allocator.free(circuit.out_wires);
        circuit.wires.deinit(allocator);
        circuit.* = undefined;
    }
};

const TestOutcome = enum { pass, fail };

fn testCircuit(
    allocator: ?std.mem.Allocator,
    circuit: Circuit,
    xs: []const [3]u8,
    ys: []const [3]u8,
    zs: []const [3]u8,
    buf: []Value,
    n: usize,
    limit: bool,
    dont_touch: ?std.AutoArrayHashMapUnmanaged([3]u8, void),
) !struct { [4]TestOutcome, ?[]const [3]u8 } {
    var outcomes: [4]TestOutcome = undefined;
    var list: std.AutoArrayHashMapUnmanaged([3]u8, void) = .{};
    defer if (allocator) |a| list.deinit(a);
    const values: [4][2]Value = .{ .{ .off, .off }, .{ .on, .off }, .{ .off, .on }, .{ .on, .on } };
    for (&values, &outcomes) |in, *outcome| {
        const x: u64 = if (in[0] == .off) 0 else @as(u64, 1) << @intCast(n);
        const y: u64 = if (in[1] == .off) 0 else @as(u64, 1) << @intCast(n);
        const z = x + y;
        const x_list = if (limit) xs[0 .. n + 1] else xs;
        const y_list = if (limit) ys[0 .. n + 1] else ys;
        try circuit.run(x_list, x, y_list, y);
        if (allocator) |a| for (circuit.wires.keys(), circuit.wires.values()) |key, value| {
            if (value == .not_yet_known) continue;
            if (dont_touch) |map| if (map.contains(key)) continue;
            try list.put(a, key, {});
        };
        try circuit.testWires(zs, buf);
        outcome.* = if (parseValue(if (limit) buf[0 .. n + 1] else buf)) |o_z| outcome: {
            const ok = if (limit) z % (@as(u64, 2) << @intCast(n)) == o_z else z == o_z;
            break :outcome if (ok) .pass else .fail;
        } else |_| .fail;
    }
    return .{ outcomes, if (allocator) |a| try a.dupe([3]u8, list.keys()) else null };
}

const Quads = struct {
    len: usize,
    data: [4]usize = .{ 0, 1, 2, 3 },

    fn next(quads: *Quads) ?[4]usize {
        if (quads.data[0] + 4 >= quads.len) return null;
        defer {
            quads.data[3] += 1;
            if (quads.data[3] + 1 >= quads.len) {
                quads.data[2] += 1;
                if (quads.data[2] + 2 >= quads.len) {
                    quads.data[1] += 1;
                    if (quads.data[1] + 3 >= quads.len) {
                        quads.data[0] += 1;
                        quads.data[1] = quads.data[0] + 1;
                    }
                    quads.data[2] = quads.data[1] + 1;
                }
                quads.data[3] = quads.data[2] + 1;
            }
        }
        return quads.data;
    }
};

fn isInput(wire: [3]u8, gates: []const Gate) bool {
    for (gates) |gate|
        if (std.mem.eql(u8, &gate.payload[0], &wire) or std.mem.eql(u8, &gate.payload[1], &wire)) return true;
    return false;
}

const ChainMaker = struct {
    gates: []const Gate,
    outs: []const [3]u8,
    xs: []const [3]u8,
    ys: []const [3]u8,
    zs: []const [3]u8,
    seen: std.AutoHashMapUnmanaged(usize, void),

    fn init(
        allocator: std.mem.Allocator,
        gates: []const Gate,
        outs: []const [3]u8,
        xs: []const [3]u8,
        ys: []const [3]u8,
        zs: []const [3]u8,
    ) !ChainMaker {
        var seen: std.AutoHashMapUnmanaged(usize, void) = .{};
        errdefer seen.deinit(allocator);
        try seen.ensureTotalCapacity(allocator, @intCast(gates.len));
        return .{
            .gates = gates,
            .outs = outs,
            .xs = xs,
            .ys = ys,
            .zs = zs,
            .seen = seen,
        };
    }

    fn deinit(maker: *ChainMaker, allocator: std.mem.Allocator) void {
        maker.seen.deinit(allocator);
        maker.* = undefined;
    }

    const RecurseRet = union(enum) {
        success: [4]usize,
        fix: [2][3]u8,
    };

    fn recurse(maker: ChainMaker, and_left: usize, level: usize) RecurseRet {
        const xor: Gate = .{
            .payload = .{ maker.xs[level], maker.ys[level] },
            .which = .xor,
        };
        var iter = xor.matchIterator(maker.gates);
        const and_right = iter.next().?;
        const @"and": Gate = .{
            .payload = .{ maker.outs[and_left], maker.outs[and_right] },
            .which = .@"and",
        };
        iter = @"and".matchIterator(maker.gates);
        const or_left = iter.next() orelse {
            // what's broken is the connection between xs[level] XOR ys[level]
            // and the other input of the AND gate
            for (maker.gates) |gate| {
                if (gate.which != .@"and") continue;
                const swap = if (std.mem.eql(u8, &maker.outs[and_left], &gate.payload[0]))
                    gate.payload[1]
                else if (std.mem.eql(u8, &maker.outs[and_left], &gate.payload[1]))
                    gate.payload[0]
                else
                    continue;
                return .{ .fix = .{ swap, maker.outs[and_right] } };
            }
            // if that didn't work, that means actually and_left needs to be swapped
            for (maker.gates) |gate| {
                if (gate.which != .@"and") continue;
                const swap = if (std.mem.eql(u8, &maker.outs[and_right], &gate.payload[0]))
                    gate.payload[1]
                else if (std.mem.eql(u8, &maker.outs[and_right], &gate.payload[1]))
                    gate.payload[0]
                else
                    continue;
                return .{ .fix = .{ swap, maker.outs[and_left] } };
            }
            unreachable; // i mean, let's just crash
        };
        const @"or": Gate = .{
            .payload = .{ maker.xs[level], maker.ys[level] },
            .which = .@"and",
        };
        iter = @"or".matchIterator(maker.gates);
        const or_right = iter.next().?;
        const match: Gate = .{
            .payload = .{ maker.outs[or_left], maker.outs[or_right] },
            .which = .@"or",
        };
        iter = match.matchIterator(maker.gates);
        const final = iter.next() orelse {
            // what's broken is the OR gate; let's see if we can fix it
            for (maker.gates) |gate| {
                if (gate.which != .@"or") continue;
                const swap = if (std.mem.eql(u8, &maker.outs[or_left], &gate.payload[0]))
                    gate.payload[1]
                else if (std.mem.eql(u8, &maker.outs[or_left], &gate.payload[1]))
                    gate.payload[0]
                else
                    continue;
                return .{ .fix = .{ swap, maker.outs[or_right] } };
            }
            // if that didn't work, that means actually or_left needs to be swapped
            for (maker.gates) |gate| {
                if (gate.which != .@"or") continue;
                const swap = if (std.mem.eql(u8, &maker.outs[or_right], &gate.payload[0]))
                    gate.payload[1]
                else if (std.mem.eql(u8, &maker.outs[or_right], &gate.payload[1]))
                    gate.payload[0]
                else
                    continue;
                return .{ .fix = .{ swap, maker.outs[or_left] } };
            }
            unreachable; // honestly, let's just crash
        };
        return .{ .success = .{ and_right, or_left, or_right, final } };
    }

    fn findExit(maker: ChainMaker, idx: usize, len: usize) ?[2]usize {
        const xor: Gate = .{
            .payload = .{ maker.xs[len], maker.ys[len] },
            .which = .xor,
        };
        var iter = xor.matchIterator(maker.gates);
        while (iter.next()) |xor_right| {
            if (maker.seen.contains(xor_right)) continue;
            const exit: Gate = .{
                .payload = .{ maker.outs[idx], maker.outs[xor_right] },
                .which = .xor,
            };
            var exit_iter = exit.matchIterator(maker.gates);
            while (exit_iter.next()) |ex| {
                if (maker.seen.contains(ex)) continue;
                return .{ xor_right, ex };
            }
        }
        return null;
    }

    const NextRet = union(enum) {
        fix: [2][3]u8,
        chain: struct { []const Gate, []const [3]u8 },
    };

    fn next(maker: *ChainMaker, allocator: std.mem.Allocator) !?NextRet {
        if (maker.seen.count() == maker.zs.len) return null;
        var indices: std.ArrayListUnmanaged(usize) = .{};
        defer indices.deinit(allocator);

        build_path: {
            const x_or: Gate = .{
                .payload = .{ maker.xs[0], maker.ys[0] },
                .which = .xor,
            };
            var iter = x_or.matchIterator(maker.gates);
            while (iter.next()) |x| {
                if (maker.seen.contains(x)) continue;
                if (isInput(maker.outs[x], maker.gates)) continue;
                try indices.append(allocator, x);
                // is this chain broken?
                if (!std.mem.eql(u8, &maker.outs[x], &maker.zs[0])) {
                    return .{ .fix = .{ maker.outs[x], maker.zs[0] } };
                }
                maker.seen.putAssumeCapacity(x, {});
                break :build_path;
            }
            const and_gate: Gate = .{
                .payload = .{ maker.xs[0], maker.ys[0] },
                .which = .@"and",
            };
            iter = and_gate.matchIterator(maker.gates);
            var x: usize = undefined;
            while (iter.next()) |n_x| {
                if (maker.seen.contains(x)) continue;
                x = n_x;
                break;
            } else return null;
            var len: usize = 1;
            while (len + 1 < maker.zs.len) {
                try indices.append(allocator, x);
                // looks for x XOR (xs[len] XOR ys[len])
                if (maker.findExit(x, len)) |tupl| {
                    const arr = try indices.addManyAsArray(allocator, 2);
                    arr.* = .{ tupl[0], tupl[1] };
                    // is this chain broken?
                    if (!std.mem.eql(u8, &maker.outs[tupl[1]], &maker.zs[len])) {
                        return .{ .fix = .{ maker.outs[tupl[1]], maker.zs[len] } };
                    }
                    maker.seen.putAssumeCapacity(tupl[1], {});
                    break;
                }
                // looks for (x AND (xs[len] XOR ys[len]) OR (xs[len] AND ys[len])
                switch (maker.recurse(x, len)) {
                    .success => |nxt| {
                        x = nxt[3];
                        const arr = try indices.addManyAsArray(allocator, 3);
                        arr.* = nxt[0..3].*;
                        len += 1;
                        continue;
                    },
                    .fix => |fix| return .{ .fix = fix },
                }
                // let's fix the exit: what's broken is the connection between x
                // and (xs[len] XOR ys[len])
                for (maker.outs, 0..) |out, i| {
                    if (!std.mem.eql(u8, &out, &maker.zs[len])) continue;
                    const gate = maker.gates[i];
                    if (gate.which != .xor) return error.UnableToFix;
                    const swap = if (std.mem.eql(u8, &maker.outs[x], &gate.payload[0]))
                        gate.payload[1]
                    else if (std.mem.eql(u8, &maker.outs[x], &gate.payload[1]))
                        gate.payload[0]
                    else
                        return error.UnableToFix;
                    const xor_gate: Gate = .{
                        .payload = .{ maker.xs[len], maker.ys[len] },
                        .which = .xor,
                    };
                    var ex_iter = xor_gate.matchIterator(maker.gates);
                    while (ex_iter.next()) |other| {
                        return .{ .fix = .{ swap, maker.outs[other] } };
                    }
                    return error.UnableToFix;
                }
            } else {
                try indices.append(allocator, x);
                if (!std.mem.eql(u8, &maker.outs[x], &maker.zs[len])) return error.Oops;
                maker.seen.putAssumeCapacity(x, {});
            }
        }
        const gates = try allocator.alloc(Gate, indices.items.len);
        errdefer allocator.free(gates);
        const outs = try allocator.alloc([3]u8, indices.items.len);
        for (indices.items, gates, outs) |i, *g_ptr, *o_ptr| {
            g_ptr.* = maker.gates[i];
            o_ptr.* = maker.outs[i];
        }
        return .{ .chain = .{ gates, outs } };
    }
};

fn process(allocator: std.mem.Allocator, input: []const u8) !Swaps {
    var circuit = try Circuit.from(allocator, input);
    defer circuit.deinit(allocator);

    var x_list: std.ArrayListUnmanaged([3]u8) = .{};
    defer x_list.deinit(allocator);
    var y_list: std.ArrayListUnmanaged([3]u8) = .{};
    defer y_list.deinit(allocator);
    var z_list: std.ArrayListUnmanaged([3]u8) = .{};
    defer z_list.deinit(allocator);

    for (circuit.wires.keys()) |key| switch (key[0]) {
        'x' => try x_list.append(allocator, key),
        'y' => try y_list.append(allocator, key),
        'z' => try z_list.append(allocator, key),
        else => {},
    };

    std.mem.sort([3]u8, x_list.items, {}, lessThan);
    std.mem.sort([3]u8, y_list.items, {}, lessThan);
    std.mem.sort([3]u8, z_list.items, {}, lessThan);

    const outs = try allocator.alloc(Value, z_list.items.len);
    defer allocator.free(outs);

    var list: std.ArrayListUnmanaged([3]u8) = .{};
    defer list.deinit(allocator);

    var maker = try ChainMaker.init(allocator, circuit.gates, circuit.out_wires, x_list.items, y_list.items, z_list.items);
    defer maker.deinit(allocator);
    var n: usize = 0;
    while (try maker.next(allocator)) |ret|
        switch (ret) {
            .chain => |tuple| {
                const gates, const out_wires = tuple;
                defer allocator.free(gates);
                defer allocator.free(out_wires);

                std.log.debug("\n\nCARRY CHAIN {}:", .{n});
                n += 1;
                for (gates, out_wires) |gate, wire| {
                    std.log.debug(
                        "{s} {s} {s} -> {s}",
                        .{ &gate.payload[0], @tagName(gate.which), &gate.payload[1], &wire },
                    );
                }
            },
            .fix => |tuple| {
                const arr = try list.addManyAsArray(allocator, 2);
                arr.* = tuple;
                var i: usize = 0;
                while (i < circuit.out_wires.len) : (i += 1) {
                    if (std.mem.eql(u8, &circuit.out_wires[i], &tuple[0])) break;
                } else unreachable;
                var j: usize = 0;
                while (j < circuit.out_wires.len) : (j += 1) {
                    if (std.mem.eql(u8, &circuit.out_wires[j], &tuple[1])) break;
                } else unreachable;
                exchange(circuit.out_wires, i, j);
            },
        };
    if (list.items.len != 8) unreachable;
    var swaps: Swaps = .{ .data = list.items[0..8].* };
    std.mem.sort([3]u8, &swaps.data, {}, lessThan);
    return swaps;
}
fn Permutations(comptime n: usize) type {
    return struct {
        const len = limit: {
            var l: usize = 1;
            var idx: usize = n;
            while (idx > 0) : (idx -= 1) l *= idx;
            break :limit l;
        };

        const it: [n]usize = it: {
            var acc: [n]usize = undefined;
            for (0..n) |i| acc[i] = i;
            break :it acc;
        };
        idx: usize = 0,
        const Self = @This();

        fn next(self: *Self) ?[n]usize {
            if (self.idx >= len) return null;
            defer self.idx += 1;
            var data: [n]usize = undefined;
            var acc: usize = len;
            for (0..n) |i| {
                const m = n - i;
                acc = @divExact(acc, m);
                // use self.idx to choose from 0 to m
                const idx = @divTrunc(self.idx, acc) % m;
                var out: usize = 0;
                var offset: usize = 0;
                var done = false;
                while (!done) : (done = (offset >= idx) and std.mem.indexOfScalar(usize, data[0..i], out) == null) {
                    while (std.mem.indexOfScalar(usize, data[0..i], out) != null) out += 1;
                    if (offset < idx) {
                        out += 1;
                        offset += 1;
                    }
                }
                data[i] = out;
            }
            return data;
        }
    };
}

test Permutations {
    var permutations: Permutations(3) = .{};
    const expected: []const [3]usize = &.{
        .{ 0, 1, 2 },
        .{ 0, 2, 1 },
        .{ 1, 0, 2 },
        .{ 1, 2, 0 },
        .{ 2, 0, 1 },
        .{ 2, 1, 0 },
    };
    for (expected) |expect| {
        const got = permutations.next() orelse return error.TestFailed;
        try std.testing.expectEqualSlices(usize, &expect, &got);
    }
    try std.testing.expectEqual(null, permutations.next());
}

fn exchange(slice: anytype, i: usize, j: usize) void {
    const tmp = slice[i];
    slice[i] = slice[j];
    slice[j] = tmp;
}

fn lessThan(_: void, a: [3]u8, b: [3]u8) bool {
    for (&a, &b) |a_byte, b_byte| {
        if (a_byte < b_byte) return true;
        if (a_byte > b_byte) return false;
    }
    return false;
}

test {
    if (true) return error.SkipZigTest;
    std.testing.log_level = .debug;
    const input_2 =
        \\x00: 1
        \\x01: 0
        \\x02: 1
        \\x03: 1
        \\x04: 0
        \\y00: 1
        \\y01: 1
        \\y02: 1
        \\y03: 1
        \\y04: 1
        \\
        \\ntg XOR fgs -> mjb
        \\y02 OR x01 -> tnw
        \\kwq OR kpj -> z05
        \\x00 OR x03 -> fst
        \\tgd XOR rvg -> z01
        \\vdt OR tnw -> bfw
        \\bfw AND frj -> z10
        \\ffh OR nrd -> bqk
        \\y00 AND y03 -> djm
        \\y03 OR y00 -> psh
        \\bqk OR frj -> z08
        \\tnw OR fst -> frj
        \\gnj AND tgd -> z11
        \\bfw XOR mjb -> z00
        \\x03 OR x00 -> vdt
        \\gnj AND wpb -> z02
        \\x04 AND y00 -> kjc
        \\djm OR pbm -> qhw
        \\nrd AND vdt -> hwm
        \\kjc AND fst -> rvg
        \\y04 OR y02 -> fgs
        \\y01 AND x02 -> pbm
        \\ntg OR kjc -> kwq
        \\psh XOR fgs -> tgd
        \\qhw XOR tgd -> z09
        \\pbm OR djm -> kpj
        \\x03 XOR y03 -> ffh
        \\x00 XOR y04 -> ntg
        \\bfw OR bqk -> z06
        \\nrd XOR fgs -> wpb
        \\frj XOR qhw -> z04
        \\bqk OR frj -> z07
        \\y03 OR x01 -> nrd
        \\hwm AND bqk -> z03
        \\tgd XOR rvg -> z12
        \\tnw OR pbm -> gnj
    ;
    const output_2 = try process(std.testing.allocator, input_2);
    std.log.debug("{}", .{output_2});
}
