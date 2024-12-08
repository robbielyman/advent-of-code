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

pub fn indexToCoordinates(newline_delimited_rectangular_ASCII_grid: []const u8, offset: usize) struct { usize, usize } {
    std.debug.assert(offset < newline_delimited_rectangular_ASCII_grid.len);
    std.debug.assert(newline_delimited_rectangular_ASCII_grid[offset] != '\n');
    // the y coordinate is the number of newlines prior to offset
    const y = countScalar(u8, newline_delimited_rectangular_ASCII_grid[0..offset], '\n');
    // the previous newline, if it exists, tells us how to find the x coordinate
    const start_of_line = std.mem.lastIndexOfScalar(u8, newline_delimited_rectangular_ASCII_grid[0..offset], '\n');
    // the x coordinate is the offset relative to the character after the newline (or from the start of the grid)
    const x = if (start_of_line) |beginning| offset - beginning - 1 else offset;
    return .{ x, y };
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

const std = @import("std");
