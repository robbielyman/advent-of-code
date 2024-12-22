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

    const output = try process(allocator, input);
    const elapsed = timer.read();

    try stdout.print("{}\n", .{output});
    try stdout.print("elapsed time: {}ms\n", .{elapsed / std.time.ns_per_ms});
    try bw.flush();
}

fn process(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var tokenizer = std.mem.tokenizeScalar(u8, input, '\n');
    var nanners: std.AutoArrayHashMapUnmanaged([4]i8, u64) = .{};
    defer nanners.deinit(allocator);
    var seen: std.AutoHashMapUnmanaged([4]i8, void) = .{};
    defer seen.deinit(allocator);
    while (tokenizer.next()) |line| {
        seen.clearRetainingCapacity();
        var secret = try std.fmt.parseInt(u64, line, 10);
        var sequence: [4]i8 = undefined;
        for (0..2000) |i| {
            const last_price: i8 = @intCast(secret % 10);
            step(&secret);
            const new_price: i8 = @intCast(secret % 10);
            if (i < 4) {
                sequence[i] = new_price - last_price;
            } else {
                sequence[0] = sequence[1];
                sequence[1] = sequence[2];
                sequence[2] = sequence[3];
                sequence[3] = new_price - last_price;
            }
            if (i < 3) continue;
            const res = try seen.getOrPut(allocator, sequence);
            if (res.found_existing) continue;
            const banana = try nanners.getOrPut(allocator, sequence);
            if (!banana.found_existing) {
                banana.value_ptr.* = @intCast(new_price);
            } else banana.value_ptr.* += @intCast(new_price);
        }
    }
    return std.mem.max(u64, nanners.values());
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
        \\2
        \\3
        \\2024
    ;
    const output = try process(std.testing.allocator, input);
    try std.testing.expectEqual(23, output);
}
