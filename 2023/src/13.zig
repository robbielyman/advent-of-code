const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const filename = try parseArgs(allocator);
    const file_contents = try getContentsOfFile(filename, allocator);
    defer allocator.free(file_contents);
    allocator.free(filename);
    const cards, const bids = try chunkLines(file_contents, allocator);
    defer allocator.free(cards);
    defer allocator.free(bids);

    const hands = try allocator.alloc(Hand, cards.len);
    defer allocator.free(hands);
    for (cards, hands, 0..) |contents, *hand, i| {
        hand.* = .{
            .kind = try Hand.Kind.fromContents(contents),
            .contents = contents,
            .id = i,
        };
    }
    std.mem.sort(Hand, hands, {}, Hand.lessThanFn);
    var count: usize = 0;
    for (hands, 1..) |hand, i| {
        const bid = try std.fmt.parseUnsigned(usize, bids[hand.id], 10);
        count += bid * i;
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("{d}\n", .{count});
    try bw.flush();
}

fn getContentsOfFile(filename: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    return try file.reader().readAllAlloc(allocator, 32 * 1024);
}

fn parseArgs(allocator: std.mem.Allocator) ![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const filename = args.next() orelse {
        std.debug.print("pass the filename as the first argument!", .{});
        std.process.exit(1);
    };
    return try allocator.dupe(u8, filename);
}

const Hand = struct {
    kind: Kind,
    contents: []const u8,
    id: usize,

    fn lessThanFn(context: void, self: Hand, other: Hand) bool {
        _ = context;
        return compare(self, other) == .lt;
    }
    
    fn compare(self: Hand, other: Hand) std.math.Order {
        const order: []const Kind = &.{.FiveOf, .FourOf, .FullHouse, .ThreeOf, .TwoPair, .OnePair, .HighCard};
        const mine = std.mem.indexOfScalar(Kind, order, self.kind).?;
        const theirs = std.mem.indexOfScalar(Kind, order, other.kind).?;
        if (mine < theirs) return .gt;
        if (mine > theirs) return .lt;
        return compareContents(self.contents, other.contents);
        
    }

    fn compareContents(self: []const u8, other: []const u8) std.math.Order {
        const order = "AKQJT98765432";
        for (self, other) |mine, theirs| {
            const my_rank = std.mem.indexOfScalar(u8, order, mine).?;
            const their_rank = std.mem.indexOfScalar(u8, order, theirs).?;
            if (my_rank < their_rank) return .gt;
            if (my_rank > their_rank) return .lt;
        }
        return .eq;
    }

    const Kind = enum {
        FiveOf,
        FourOf,
        FullHouse,
        ThreeOf,
        TwoPair,
        OnePair,
        HighCard,
        fn fromContents(contents: []const u8) !Kind {
            if (contents.len != 5) return error.ParseFailed;
            const num_matches: []const u8 = num_matches: {
                var num_matches: [5]u8 = undefined;
                @memset(&num_matches, 0);
                for (contents, 0..) |value, i| {
                    for (contents) |other| {
                        if (value == other) num_matches[i] += 1;
                    }
                    switch (num_matches[i]) {
                        5 => return .FiveOf,
                        4 => return .FourOf,
                        else => {},
                    }
                }
                break :num_matches &num_matches;
            };
            switch (std.mem.max(u8, num_matches)) {
                3 => if (std.mem.indexOfScalar(u8, num_matches, 2)) |_|
                    return .FullHouse
                else
                    return .ThreeOf,
                2 => {
                    const sum = sum: {
                        var count: usize = 0;
                        for (num_matches) |match| {
                            count += match;
                        }
                        break :sum count;
                    };
                    if (sum <= 7) return .OnePair else return .TwoPair;
                },
                1 => return .HighCard,
                else => return error.ParseFailed,
            }
        }
    };
};

test "sortHands" {
    const contents: []const []const u8 = &.{ "32T3K", "T55J5", "KK677", "KTJJT", "QQQJA" };
    const ranks: []const usize = &.{ 1, 4, 3, 2, 5 };
    const hands = try std.testing.allocator.alloc(Hand, contents.len);
    defer std.testing.allocator.free(hands);
    for (contents, hands, 1..) |cards, *hand, i| {
        hand.* = .{
            .kind = try Hand.Kind.fromContents(cards),
            .contents = cards,
            .id = i,
        };
    }
    std.mem.sort(Hand, hands, {}, Hand.lessThanFn);
    for (hands, ranks) |hand, rank| {
        try std.testing.expectEqual(rank, hand.id);
    }
}

test "fromContents" {
    const contents: []const []const u8 = &.{ "32T3K", "T55J5", "KK677", "KTJJT", "QQQJA" };
    const kinds: []const Hand.Kind = &.{ .OnePair, .ThreeOf, .TwoPair, .TwoPair, .ThreeOf };
    for (contents, kinds) |hand, kind| {
        const got = try Hand.Kind.fromContents(hand);
        try std.testing.expectEqual(kind, got);
    }
}

fn chunkLines(contents: []const u8, allocator: std.mem.Allocator) ![2][]const []const u8 {
    var hands = std.ArrayList([]const u8).init(allocator);
    var bids = std.ArrayList([]const u8).init(allocator);
    defer hands.deinit();
    defer bids.deinit();
    var iterator = std.mem.tokenizeScalar(u8, contents, '\n');
    while (iterator.next()) |line| {
        var chunker = std.mem.tokenizeScalar(u8, line, ' ');
        try hands.append(chunker.next() orelse return error.ParseFailed);
        try bids.append(chunker.next() orelse return error.ParseFailed);
        if (chunker.next() != null) return error.ParseFailed;
    }
    return .{ try hands.toOwnedSlice(), try bids.toOwnedSlice() };
}

test "chunkLines" {
    const test_input =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;
    const expected_hands: []const []const u8 = &.{ "32T3K", "T55J5", "KK677", "KTJJT", "QQQJA" };
    const expected_bids: []const []const u8 = &.{ "765", "684", "28", "220", "483" };
    const hands, const bids = try chunkLines(test_input, std.testing.allocator);
    defer std.testing.allocator.free(hands);
    defer std.testing.allocator.free(bids);
    for (expected_hands, hands) |expected, hand| {
        try std.testing.expectEqualStrings(expected, hand);
    }
    for (expected_bids, bids) |expected, bid| {
        try std.testing.expectEqualStrings(expected, bid);
    }
}
