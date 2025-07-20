const std = @import("std");

const State = enum { group, garbage };

pub fn process(_: std.mem.Allocator, input: []const u8) !u32 {
    var ret: u32 = 0;
    var idx: usize = 0;
    loop: switch (State.group) {
        .group => {
            const char = input[idx];
            idx += 1;
            switch (char) {
                '{' => continue :loop .group,
                '<' => continue :loop .garbage,
                '}' => {
                    if (idx < input.len) {
                        if (input[idx] == ',') idx += 1;
                        continue :loop .group;
                    }
                },
                else => return error.Invalid,
            }
        },
        .garbage => {
            const char = input[idx];
            idx += 1;
            switch (char) {
                '!' => {
                    idx += 1;
                    continue :loop .garbage;
                },
                '>' => {
                    if (input[idx] == ',') idx += 1;
                    continue :loop .group;
                },
                else => {
                    ret += 1;
                    continue :loop .garbage;
                },
            }
        },
    }
    return ret;
}

test process {
    const inputs: []const []const u8 = &.{
        "{<>}",
        "{<random characters>}",
        "{<<<<>}",
        "{<{!>}>}",
        "{<!!>}",
        "{<!!!>>}",
        "{<{o\"i!a,<{i<a>}",
    };
    const scores: []const u32 = &.{ 0, 17, 3, 2, 0, 0, 10 };
    for (inputs, scores) |input, expected|
        try std.testing.expectEqual(expected, try process(std.testing.allocator, input));
}
