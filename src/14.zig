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
        std.debug.print("Hand {d}: kind: {s}, contents: {s}\n", .{ i, @tagName(hand.kind), hand.contents });
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
        const order: []const Kind = &.{ .FiveOf, .FourOf, .FullHouse, .ThreeOf, .TwoPair, .OnePair, .HighCard };
        const mine = std.mem.indexOfScalar(Kind, order, self.kind).?;
        const theirs = std.mem.indexOfScalar(Kind, order, other.kind).?;
        if (mine < theirs) return .gt;
        if (mine > theirs) return .lt;
        return compareContents(self.contents, other.contents);
    }

    fn compareContents(self: []const u8, other: []const u8) std.math.Order {
        const order = "AKQT98765432J";
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
            var unique: [5]u8 = undefined;
            var counts: [5]u8 = undefined;
            var id: usize = 0;
            var num_jokers: usize = 0;
            for (contents) |char| {
                if (char == 'J') {
                    num_jokers += 1;
                    continue;
                }
                var found = false;
                for (unique[0..id], 0..) |value, i| {
                    if (char == value) {
                        found = true;
                        counts[i] += 1;
                        break;
                    }
                }
                if (!found) {
                    unique[id] = char;
                    counts[id] = 1;
                    id += 1;
                }
            }
            switch (num_jokers) {
                0 => {
                    switch (id) {
                        1 => return .FiveOf,
                        2 => if (counts[0] == 3 or counts[1] == 3) {
                            return .FullHouse;
                        } else {
                            return .FourOf;
                        },
                        3 => if (counts[0] == 3 or counts[1] == 3 or counts[2] == 3) {
                            return .ThreeOf;
                        } else {
                            return .TwoPair;
                        },
                        4 => return .OnePair,
                        5 => return .HighCard,
                        else => return error.ParseFailed,
                    }
                },
                1 => {
                    switch (id) {
                        // one joker and four of another card
                        1 => return .FiveOf,
                        2 => {
                            if (counts[0] == 3 or counts[1] == 3) {
                                // one joker, three of another card and a final one;
                                return .FourOf;
                            } else {
                                // one joker and two pairs
                                return .FullHouse;
                            }
                        },
                        // one joker and one pair
                        3 => return .ThreeOf,
                        4 => return .OnePair,
                        else => return error.ParseFailed,
                    }
                },
                2 => {
                    switch (id) {
                        // two jokers and one other card
                        1 => return .FiveOf,
                        // two jokers and at least one pair
                        2 => return .FourOf,
                        // two jokers and three other cards
                        3 => return .ThreeOf,
                        else => return error.ParseFailed,
                    }
                },
                3 => {
                    switch (id) {
                        // three jokers, one other card
                        1 => return .FiveOf,
                        // three jokers and two other cards
                        2 => return .FourOf,
                        else => return error.ParseFailed,
                    }
                },
                // this many jokers is automatically .FiveOf
                4, 5 => return .FiveOf,
                else => return error.ParseFailed,
            }
        }
    };
};

test "fullParse" {
    const input =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;
    const allocator = std.testing.allocator;
    const contents, const bids = try chunkLines(input, allocator);
    defer allocator.free(contents);
    defer allocator.free(bids);
    const hands = try allocator.alloc(Hand, contents.len);
    defer allocator.free(hands);
    for (contents, hands, 0..) |content, *hand, i| {
        hand.* = .{
            .kind = try Hand.Kind.fromContents(content),
            .contents = content,
            .id = i,
        };
    }
    std.mem.sort(Hand, hands, {}, Hand.lessThanFn);
    var count: usize = 0;
    for (hands, 1..) |hand, i| {
        const bid = try std.fmt.parseUnsigned(usize, bids[hand.id], 10);
        count += bid * i;
    }
    try std.testing.expectEqual(@as(usize, 5905), count);
}

test "fromContents2" {
    const contents: []const []const u8 = &.{ "32J32", "T55JA", "J1234", "11223" };
    const kinds: []const Hand.Kind = &.{ .FullHouse, .ThreeOf, .OnePair, .TwoPair };
    for (contents, kinds) |hand, kind| {
        const got = try Hand.Kind.fromContents(hand);
        try std.testing.expectEqual(kind, got);
    }
}

test "sortHands" {
    const contents: []const []const u8 = &.{ "32T3K", "T55J5", "KK677", "KTJJT", "QQQJA" };
    const ranks: []const usize = &.{ 1, 3, 2, 5, 4 };
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
    const kinds: []const Hand.Kind = &.{ .OnePair, .FourOf, .TwoPair, .FourOf, .FourOf };
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
