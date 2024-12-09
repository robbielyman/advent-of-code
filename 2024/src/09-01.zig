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

    var defragged: std.ArrayListUnmanaged(u16) = .{};
    defer defragged.deinit(allocator);
    var read_head: usize = 0;
    var copy_head: usize = fragged.items.len - 1;
    var copy = if (fragged.items[copy_head].id == .free) copy: {
        copy_head -= 1;
        break :copy fragged.items[copy_head];
    } else fragged.items[copy_head];
    var copy_len = copy.len;
    while (read_head < copy_head) {
        const read = fragged.items[read_head];
        switch (read.id) {
            .free => {
                var slice = try defragged.addManyAsSlice(allocator, read.len);
                var len = @min(copy_len, slice.len);
                @memset(slice[0..len], copy.id.file);
                while (len < slice.len) {
                    // we finished reading a file
                    slice = slice[len..];
                    copy_head -= 2;
                    copy = fragged.items[copy_head];
                    copy_len = copy.len;
                    len = @min(copy_len, slice.len);
                    @memset(slice[0..len], copy.id.file);
                }
                // we have leftover length in copy_len
                copy_len -= len;
                read_head += 1;
            },
            .file => |file_id| {
                const slice = try defragged.addManyAsSlice(allocator, read.len);
                @memset(slice, file_id);
                read_head += 1;
            },
        }
    }
    if (read_head == copy_head and copy_len > 0) {
        const slice = try defragged.addManyAsSlice(allocator, copy_len);
        @memset(slice, copy.id.file);
    }
    var checksum: usize = 0;
    for (defragged.items, 0..) |file_id, pos| checksum += file_id * pos;
    return checksum;
}

test {
    const input = "2333133121414131402";

    const output = try process(std.testing.allocator, input);

    try std.testing.expectEqual(1928, output);
}
