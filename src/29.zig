const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = input: {
        const filename = try parseArgs(allocator);
        defer allocator.free(filename);
        break :input try readInput(allocator, filename);
    };
    defer allocator.free(input);

    var tokenizer = std.mem.tokenizeScalar(u8, input, ',');
    var count: usize = 0;
    while (tokenizer.next()) |chunk| {
        count += hashAlgorithm(chunk);
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn readInput(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    const reader = file.reader();
    defer file.close();
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    reader.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
        if (err != error.EndOfStream) return err;
    };
    return try buffer.toOwnedSlice();
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

fn hashAlgorithm(input: []const u8) usize {
    var count: usize = 0;
    for (input) |char| {
        count += char;
        count *= 17;
        count = count % 256;
    }
    return count;
}

test "hashAlgorithm" {
    const input = "rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7";
    const output: []const usize = &.{
        30, 253, 97, 47, 14, 180, 9, 197, 48, 214, 231,
    };
    var idx: usize = 0;
    var tokenizer = std.mem.tokenizeScalar(u8, input, ',');
    while (tokenizer.next()) |chunk| : (idx += 1) {
        try std.testing.expectEqual(output[idx], hashAlgorithm(chunk));
    }
}
