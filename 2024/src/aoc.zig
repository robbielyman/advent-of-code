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

const std = @import("std");
