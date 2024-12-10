pub const Direction = enum {
    north,
    east,
    south,
    west,
    northeast,
    northwest,
    southeast,
    southwest,

    pub fn walk(where: Direction, x: usize, y: usize, x_max: usize, y_max: usize) error{Overflow}!struct { usize, usize } {
        return switch (where) {
            .north => if (y == 0) error.Overflow else .{ x, y - 1 },
            .east => if (x == x_max) error.Overflow else .{ x + 1, y },
            .south => if (y == y_max) error.Overflow else .{ x, y + 1 },
            .west => if (x == 0) error.Overflow else .{ x - 1, y },
            .northeast => if (x == x_max or y == 0) error.Overflow else .{ x + 1, y - 1 },
            .northwest => if (x == 0 or y == 0) error.Overflow else .{ x - 1, y - 1 },
            .southeast => if (x == x_max or y == y_max) error.Overflow else .{ x + 1, y + 1 },
            .southwest => if (x == 0 or y == y_max) error.Overflow else .{ x - 1, y + 1 },
        };
    }
};

pub fn dimensions(newline_delimited_rectangular_ASCII_grid: []const u8) struct { usize, usize } {
    const not_off_by_one = newline_delimited_rectangular_ASCII_grid[newline_delimited_rectangular_ASCII_grid.len - 1] == '\n';
    const y = countScalar(u8, newline_delimited_rectangular_ASCII_grid, '\n');
    const x = std.mem.indexOfScalar(u8, newline_delimited_rectangular_ASCII_grid, '\n').?;
    return .{ x, if (not_off_by_one) y else y + 1 };
}

pub fn countScalar(comptime T: type, haystack: []const T, needle: T) usize {
    var found: usize = 0;
    for (haystack) |straw| {
        if (straw == needle) found += 1;
    }
    return found;
}

pub fn isInBox(comptime Int: type, min_corner: [2]Int, max_corner: [2]Int, coord: [2]Int) bool {
    return coord[0] >= min_corner[0] and coord[0] <= max_corner[0] and
        coord[1] >= min_corner[1] and coord[1] <= max_corner[1];
}

/// for a buffer of length len
/// representing a rectangular grid with identically-spaced delimiters at line endings,
/// returns the (x,y) coordinate corresponding to a given offset
pub fn indexToCoordinates(offset: usize, len: usize, line_length: usize) error{ Overflow, Delimiter }!struct { usize, usize } {
    if (offset >= len) return error.Overflow;
    // in 1-indexing, the first delimiter (which isn't actually there) is at index 0,
    // the next is at line_length, then 2 * line_length, and so on...
    // so we add 1 to the offset to compute the line.
    const one_indexed = offset + 1;
    // the one-indexed x-coordinate is how far past
    // the most recent multiple of line_length we are
    const one_indexed_x = one_indexed % line_length;
    if (one_indexed_x == 0) return error.Delimiter;
    // this number is already correctly zero-indexed
    const y = @divFloor(one_indexed, line_length);
    return .{ one_indexed_x - 1, y };
}

test {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    const max_x, const max_y = dimensions(input);
    try std.testing.expectEqualSlices(usize, &.{ 8, 8 }, &.{ max_x, max_y });
    const expectations: []const [2]usize = &.{
        .{ 0, 2 },
        .{ 0, 4 },
        .{ 2, 4 },
        .{ 4, 6 },
        .{ 5, 2 },
        .{ 5, 5 },
        .{ 6, 0 },
        .{ 6, 6 },
        .{ 7, 1 },
    };
    var i: usize = 0;
    var idx: usize = 0;
    while (std.mem.indexOfScalarPos(u8, input, i, '0')) |offset| {
        i = offset + 1;
        const x, const y = try indexToCoordinates(offset, input.len, max_x + 1);
        const e_y, const e_x = expectations[idx];
        idx += 1;
        try std.testing.expectEqualSlices(usize, &.{ e_x, e_y }, &.{ x, y });
    }
    const directions: []const Direction = &.{ .north, .east, .south, .west, .northeast, .northwest, .southeast, .southwest };
    const expected_neighbors = "91890809";
    var neighbors: [8]u8 = undefined;
    for (directions, 0..) |direction, j| {
        const x, const y = try direction.walk(5, 5, max_x - 1, max_y - 1);
        const offset = try coordinatesToIndex(x, y, max_x, max_y);
        neighbors[j] = input[offset];
    }
    try std.testing.expectEqualStrings(expected_neighbors, &neighbors);
}

/// for a rectangular, newline delimited ASCII grid
/// returns the byte offset for a given coordinate
/// x_max and y_max should be one more than the actually occurring possible values
/// for x and y respectively
pub fn coordinatesToIndex(x: usize, y: usize, x_max: usize, y_max: usize) error{OutOfBounds}!usize {
    if (x >= x_max or y >= y_max) return error.OutOfBounds;
    return (y * (x_max + 1)) + x;
}

const std = @import("std");
