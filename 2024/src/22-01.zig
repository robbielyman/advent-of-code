const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("22.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = bw.writer();
    var timer = try std.time.Timer.start();

    const output = try process(input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}us\n", .{elapsed / std.time.ns_per_us});
    try bw.flush();
}

fn process(input: []const u8) !u64 {
    var count: u64 = 0;
    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    while (tokenizer.next()) |line| {
        var secret = try std.fmt.parseInt(u64, line, 10);
        for (0..2000) |_| step(&secret);
        count += secret;
    }
    return count;
}

fn mix(secret: *u64, input: u64) void {
    secret.* ^= input;
}

fn prune(secret: *u64) void {
    secret.* %= 16777216;
}

fn step(secret: *u64) void {
    mix(secret, secret.* * 64);
    prune(secret);
    mix(secret, @divTrunc(secret.*, 32));
    prune(secret);
    mix(secret, secret.* * 2048);
    prune(secret);
}

test {
    const input =
        \\1
        \\10
        \\100
        \\2024
    ;
    const output = try process(input);
    try std.testing.expectEqual(37327623, output);
}
