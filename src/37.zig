const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const filename = try parseArgs(allocator);
    const contents = try getFileContents(filename, allocator);
    defer allocator.free(contents);
    allocator.free(filename);
    var tokenizer = std.mem.splitScalar(u8, contents, '\n');
    var parse_as_part = false;
    var count: usize = 0;
    var map = Map.init(allocator);
    defer map.deinit();
    while (tokenizer.next()) |line| {
        if (line.len == 0) {
            parse_as_part = true;
            continue;
        }
        if (parse_as_part) {
            const part = try parsePart(line);
            count += try process(part, &map);
        } else {
            try addToMap(line, &map);
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try stdout.print("time: {d}ms\n", .{@divTrunc(timer.read(), std.time.ns_per_ms)});
    try bw.flush();
}

fn getFileContents(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 32 * 1024);
} 

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse return error.FilenameNotFound;
    return try allocator.dupe(u8, filename);
}

const Part = struct {
    x: usize,
    m: usize,
    a: usize,
    s: usize,
};

const Map = std.StringHashMap([]const u8);

fn addToMap(line: []const u8, map: *Map) !void {
    var tokenizer = std.mem.tokenizeAny(u8, line, "{}");
    const key = tokenizer.next() orelse return error.ParseFailed;
    const val = tokenizer.next() orelse return error.ParseFailed;
    try map.put(key, val);
}

fn parsePart(line: []const u8) !Part {
    const x, const m, const a, const s = xmas: {
        var x: ?usize = null;
        var m: ?usize = null;
        var a: ?usize = null;
        var s: ?usize = null;
        var tokenizer = std.mem.tokenizeAny(u8, line, "{},");
        while (tokenizer.next()) |token| {
            const number = try std.fmt.parseUnsigned(usize, token[2..], 10);
            switch (token[0]) {
                'x' => x = number,
                'm' => m = number,
                'a' => a = number,
                's' => s = number,
                else => return error.ParseFailed,
            }
        }
        break :xmas .{
            x orelse return error.ParseFailed,
            m orelse return error.ParseFailed,
            a orelse return error.ParseFailed,
            s orelse return error.ParseFailed,
        };
    };
    return .{ .x = x, .m = m, .a = a, .s = s };
}

test "end-to-end" {
    const input =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;
    const keys: []const []const u8 = &.{
        "px", "pv", "lnx", "rfg", "qs", "qkq", "crn", "in", "qqz", "gd", "hdj",
    };
    const vals: []const []const u8 = &.{
        "a<2006:qkq,m>2090:A,rfg",
        "a>1716:R,A",
        "m>1548:A,A",
        "s<537:gd,x>2440:R,A",
        "s>3448:A,lnx",
        "x<1416:A,crn",
        "x>2662:A,R",
        "s<1351:px,qqz",
        "s>2770:qs,m<1801:hdj,R",
        "a>3333:R,R",
        "m>838:A,pv",
    };
    const got_parts: []const Part = &.{
        .{ .x = 787, .m = 2655, .a = 1222, .s = 2876 },
        .{ .x = 1679, .m = 44, .a = 2067, .s = 496 },
        .{ .x = 2036, .m = 264, .a = 79, .s = 2244 },
        .{ .x = 2461, .m = 1339, .a = 466, .s = 291 },
        .{ .x = 2127, .m = 1623, .a = 2188, .s = 1013 },
    };
    var map = Map.init(std.testing.allocator);
    var parts = std.ArrayList(Part).init(std.testing.allocator);
    defer parts.deinit();
    defer map.deinit();
    var parse_as_part = false;
    var tokenizer = std.mem.splitScalar(u8, input, '\n');
    while (tokenizer.next()) |token| {
        if (token.len == 0) {
            parse_as_part = true;
            continue;
        }
        if (!parse_as_part) {
            try addToMap(token, &map);
        } else {
            try parts.append(try parsePart(token));
        }
    }
    for (keys, vals) |key, val| {
        const got = map.get(key) orelse return error.TestFailed;
        try std.testing.expectEqualStrings(val, got);
    }
    var count: usize = 0;
    for (parts.items, got_parts) |part, val| {
        try std.testing.expectEqualDeep(part, val);
        count += try process(part, &map);
    }
    try std.testing.expectEqual(@as(usize, 19114), count);
}

fn process(part: Part, map: *Map) !usize {
    const in = "in";
    var directions = map.get(in) orelse return error.ProcessFailed;
    var accept: ?bool = null;
    while (accept == null) {
        var tokenizer = std.mem.tokenizeScalar(u8, directions, ',');
        while (tokenizer.next()) |direction| {
            if (std.mem.indexOfScalar(u8, direction, ':')) |idx| {
                const comparand = switch (direction[0]) {
                    'x' => part.x,
                    'm' => part.m,
                    'a' => part.a,
                    's' => part.s,
                    else => return error.ParseFailed,
                };
                const number = try std.fmt.parseUnsigned(usize, direction[2..idx], 10);
                const outcome = switch (direction[1]) {
                    '>' => comparand > number,
                    '<' => comparand < number,
                    else => return error.ProcessFailed,
                };
                if (outcome) {
                    switch (direction[idx + 1]) {
                        'R' => {
                            accept = false;
                            break;
                        },
                        'A' => {
                            accept = true;
                            break;
                        },
                        else => {
                            const key = direction[idx + 1 ..];
                            directions = map.get(key) orelse return error.ProcessFailed;
                            break;
                        },
                    }
                }
            } else {
                switch (direction[0]) {
                    'R' => {
                        accept = false;
                        break;
                    },
                    'A' => {
                        accept = true;
                        break;
                    },
                    else => {
                        directions = map.get(direction) orelse return error.ProcessFailed;
                        break;
                    },
                }
            }
        } else return error.ProcessFailed;
    }
    return if (accept orelse return error.ProcessFailed)
        part.x + part.m + part.a + part.s
    else
        0;
}
