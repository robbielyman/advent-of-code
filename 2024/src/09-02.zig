const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("09.txt", .{});
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

const Block = struct {
    id: Id,
    len: u8,

    const Id = union(enum) {
        free: void,
        file: u16,
    };
};

fn process(allocator: std.mem.Allocator, input: []const u8) !usize {
    var fragged: std.ArrayListUnmanaged(Block) = .{};
    defer fragged.deinit(allocator);
    var free = false;
    var id: u16 = 0;
    try fragged.ensureTotalCapacity(allocator, input.len);

    for (input) |byte| {
        defer free = !free;
        const digit = switch (byte) {
            '0'...'9' => byte - '0',
            else => continue,
        };
        const file: Block.Id = if (free) .free else id: {
            defer id += 1;
            break :id .{ .file = id };
        };
        fragged.appendAssumeCapacity(.{ .id = file, .len = digit });
    }

    var idx = fragged.items.len - 1;
    var pos: usize = 0;
    for (fragged.items) |block| {
        pos += block.len;
    }

    while (idx > 0) {
        const block = &fragged.items[idx];
        pos -= block.len;
        if (block.id == .free) {
            idx -= 1;
            continue;
        }
        var new_pos: usize = 0;
        var i: usize = 0;
        while (new_pos < pos) : (i += 1) {
            const item = &fragged.items[i];
            const item_len = item.len;
            defer new_pos += item_len;
            if (item.id != .free or item.len < block.len) continue;
            if (item.len == block.len) {
                // perfect fit
                item.id = block.id;
                block.id = .free;
                idx -= 1;
                break;
            }
            const rem = item.len - block.len;
            item.* = block.*;
            block.id = .free;
            try fragged.insert(allocator, i + 1, .{ .id = .free, .len = rem });
            break;
        } else {
            idx -= 1;
        }
    }

    var checksum: usize = 0;
    pos = 0;
    for (fragged.items) |block| {
        switch (block.id) {
            .free => pos += block.len,
            .file => |file_id| {
                for (0..block.len) |i| {
                    checksum += file_id * (pos + i);
                }
                pos += block.len;
            },
        }
    }
    return checksum;
}

test {
    const input = "2333133121414131402";

    const output = try process(std.testing.allocator, input);

    try std.testing.expectEqual(2858, output);
}
