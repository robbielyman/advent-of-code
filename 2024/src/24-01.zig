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

const Gate = union(enum) {
    @"and": [3]u8,
    xor: [3]u8,
    @"or": [3]u8,
};

const Value = enum { on, off, not_yet_known };

fn process(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var wires: std.AutoArrayHashMapUnmanaged([3]u8, Value) = .{};
    defer wires.deinit(allocator);

    const split = std.mem.indexOf(u8, input, "\n\n") orelse return error.BadInput;
    {
        var iterator = std.mem.tokenizeScalar(u8, input[0..split], '\n');
        while (iterator.next()) |line| {
            try wires.put(allocator, line[0..3].*, switch (line[line.len - 1]) {
                '1' => .on,
                '0' => .off,
                else => return error.BadInput,
            });
        }
        std.log.debug("finished parsing provided wires", .{});
    }

    var gates: std.AutoArrayHashMapUnmanaged(Gate, [2][3]u8) = .{};
    defer gates.deinit(allocator);
    {
        var iterator = std.mem.tokenizeScalar(u8, input[split + 2 ..], '\n');
        while (iterator.next()) |line| {
            var gate_wires: [3][3]u8 = undefined;
            if (std.mem.indexOf(u8, line, "AND")) |_| {
                gate_wires[0] = line[0..3].*;
                gate_wires[1] = line[3 + 3 + 2 ..][0..3].*;
                gate_wires[2] = line[3 + 3 + 3 + 2 + 2 + 2 ..][0..3].*;
                try gates.put(allocator, .{ .@"and" = gate_wires[2] }, .{ gate_wires[0], gate_wires[1] });
            } else if (std.mem.indexOf(u8, line, "XOR")) |_| {
                gate_wires[0] = line[0..3].*;
                gate_wires[1] = line[3 + 3 + 2 ..][0..3].*;
                gate_wires[2] = line[3 + 3 + 3 + 2 + 2 + 2 ..][0..3].*;
                try gates.put(allocator, .{ .xor = gate_wires[2] }, .{ gate_wires[0], gate_wires[1] });
            } else { // OR gate
                gate_wires[0] = line[0..3].*;
                gate_wires[1] = line[3 + 2 + 2 ..][0..3].*;
                gate_wires[2] = line[3 + 2 + 3 + 2 + 2 + 2 ..][0..3].*;
                try gates.put(allocator, .{ .@"or" = gate_wires[2] }, .{ gate_wires[0], gate_wires[1] });
            }
            for (&gate_wires) |wire| {
                const res = try wires.getOrPut(allocator, wire);
                if (res.found_existing) continue;
                res.value_ptr.* = .not_yet_known;
            }
        }
        std.log.debug("finished parsing gates", .{});
    }
    var done = false;
    while (!done) {
        var counter: usize = 0;
        {
            gates.lockPointers();
            defer gates.unlockPointers();
            for (gates.values(), gates.keys()) |gate, output| {
                const a = wires.get(gate[0]).?;
                if (a == .not_yet_known) continue;
                const b = wires.get(gate[1]).?;
                if (b == .not_yet_known) continue;
                const c = switch (output) {
                    inline else => |v| v,
                };
                const out_wire_ptr = wires.getPtr(c).?;
                if (out_wire_ptr.* != .not_yet_known) continue;
                out_wire_ptr.* = switch (output) {
                    .@"and" => if (a == .on and b == .on) .on else .off,
                    .xor => if (a == b) .off else .on,
                    .@"or" => if (a == .on or b == .on) .on else .off,
                };
                counter += 1;
            }
        }
        if (counter > 0) try wires.reIndex(allocator);

        std.log.debug("updated {} wires", .{counter});
        if (counter == 0) {
            for (wires.keys(), wires.values()) |key, value| {
                std.log.debug("wire {s}: {s}", .{ &key, @tagName(value) });
            }
        }
        for (wires.keys(), wires.values()) |key, val| {
            if (key[0] == 'z' and val == .not_yet_known) {
                done = false;
                std.debug.assert(counter > 0);
                break;
            }
        } else done = true;
    }
    std.log.debug("finished updating wires", .{});
    var list: std.ArrayListUnmanaged([3]u8) = .{};
    defer list.deinit(allocator);

    for (wires.keys()) |wire| if (wire[0] == 'z') try list.append(allocator, wire);
    std.mem.sort([3]u8, list.items, {}, lessThan);
    var out: u64 = 0;
    for (list.items, 0..) |wire, i| {
        if (wires.get(wire).? == .on) out += @as(u64, 1) << @intCast(i);
    }
    return out;
}

fn lessThan(_: void, a: [3]u8, b: [3]u8) bool {
    for (&a, &b) |a_byte, b_byte| {
        if (a_byte < b_byte) return true;
        if (a_byte > b_byte) return false;
    }
    return false;
}

test {
    std.testing.log_level = .debug;
    const input =
        \\x00: 1
        \\x01: 1
        \\x02: 1
        \\y00: 0
        \\y01: 1
        \\y02: 0
        \\
        \\x00 AND y00 -> z00
        \\x01 XOR y01 -> z01
        \\x02 OR y02 -> z02
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(4, output);
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
    try std.testing.expectEqual(2024, output_2);
}
