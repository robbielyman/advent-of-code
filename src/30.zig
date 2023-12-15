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
    var boxes: [256]Box = undefined;
    @memset(&boxes, .{});
    while (tokenizer.next()) |instruction| {
        try processInstruction(allocator, instruction, &boxes);
    }

    var count: usize = 0;
    for (&boxes, 1..) |*box, i| {
        var lens_nr: usize = 1;
        while (box.dequeue()) |lens| : (lens_nr += 1) {
            count += i * lens_nr * lens.focal_length;
            allocator.destroy(lens);
        }
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

const Box = struct {
    first_lens: ?*Lens = null,
    last_lens: ?*Lens = null,
    length: usize = 0,

    const Lens = struct {
        label: []const u8,
        focal_length: usize,
        prev: ?*Lens = null,
        next: ?*Lens = null,
    };

    fn remove(self: *Box, label: []const u8) ?*Lens {
        var curr = self.first_lens;
        while (curr) |lens| {
            if (std.mem.eql(u8, lens.label, label)) {
                if (lens.prev) |p| p.next = lens.next;
                if (lens.next) |n| n.prev = lens.prev;
                if (lens == self.first_lens) self.first_lens = lens.next;
                if (lens == self.last_lens) self.last_lens = lens.prev;
                self.length -= 1;
                return lens;
            }
            curr = lens.next;
        }
        return null;
    }

    fn replaceOrAdd(self: *Box, new: *Lens) ?*Lens {
        var curr = self.first_lens;
        while (curr) |lens| {
            if (std.mem.eql(u8, lens.label, new.label)) {
                new.prev = lens.prev;
                new.next = lens.next;
                if (new.prev) |p| p.next = new;
                if (new.next) |n| n.prev = new;
                if (curr == self.first_lens) self.first_lens = new;
                if (curr == self.last_lens) self.last_lens = new;
                return lens;
            }
            curr = lens.next;
        } else {
            if (self.last_lens) |last| {
                last.next = new;
                new.prev = last;
            } else {
                self.first_lens = new;
            }
            self.last_lens = new;
            self.length += 1;
            return null;
        }
    }

    fn dequeue(self: *Box) ?*Lens {
        if (self.first_lens) |lens| {
            self.first_lens = lens.next;
            self.length -= 1;
            if (self.length == 0) self.last_lens = null;
            return lens;
        }
        return null;
    }
};

fn processInstruction(
    allocator: std.mem.Allocator,
    instruction: []const u8,
    boxes: []Box,
) !void {
    if (std.mem.indexOfScalar(u8, instruction, '-')) |idx| {
        const box_number = hashAlgorithm(instruction[0..idx]);
        const lens = boxes[box_number].remove(instruction[0..idx]);
        if (lens) |l| allocator.destroy(l);
        return;
    }
    if (std.mem.indexOfScalar(u8, instruction, '=')) |idx| {
        const focal_length = try std.fmt.parseUnsigned(usize, instruction[idx + 1 ..], 10);
        const lens = try allocator.create(Box.Lens);
        lens.* = .{
            .label = instruction[0..idx],
            .focal_length = focal_length,
            .next = null,
            .prev = null,
        };
        const box_number = hashAlgorithm(instruction[0..idx]);
        const old = boxes[box_number].replaceOrAdd(lens);
        if (old) |o| allocator.destroy(o);
        return;
    }
    return error.ParseFailed;
}

test "processInstruction" {
    const input = "rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7";
    var boxes: [256]Box = undefined;
    @memset(&boxes, .{});
    var tokenizer = std.mem.tokenizeScalar(u8, input, ',');
    const allocator = std.testing.allocator;
    var step_number: usize = 0;
    while (tokenizer.next()) |instruction| : (step_number += 1) {
        try processInstruction(allocator, instruction, &boxes);
        std.log.info("\nSTEP NUMBER {d}\n", .{step_number});
        for (boxes, 0..) |box, i| {
            if (box.length != 0) {
                std.log.info("BOX {d}:\n", .{i});
                var curr = box.first_lens;
                while (curr) |lens| {
                    std.log.info("label: {s}, focal_length: {d}\n", .{ lens.label, lens.focal_length });
                    curr = lens.next;
                }
            }
        }
    }
    const box_0: []const Box.Lens = &.{
        .{ .label = "rn", .focal_length = 1 },
        .{ .label = "cm", .focal_length = 2 },
    };
    const box_3: []const Box.Lens = &.{
        .{ .label = "ot", .focal_length = 7 },
        .{ .label = "ab", .focal_length = 5 },
        .{ .label = "pc", .focal_length = 6 },
    };
    var curr = boxes[0].first_lens;
    for (box_0) |lens| {
        const got = curr orelse return error.TestFailed;
        try std.testing.expectEqualStrings(lens.label, got.label);
        try std.testing.expectEqual(lens.focal_length, got.focal_length);
        curr = got.next;
        allocator.destroy(got);
    }
    curr = boxes[3].first_lens;
    for (box_3) |lens| {
        const got = curr orelse return error.TestFailed;
        try std.testing.expectEqualStrings(lens.label, got.label);
        try std.testing.expectEqual(lens.focal_length, got.focal_length);
        curr = got.next;
        allocator.destroy(got);
    }
}
