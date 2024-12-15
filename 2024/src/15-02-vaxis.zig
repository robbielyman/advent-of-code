const std = @import("std");
const aoc = @import("aoc.zig");
const vaxis = @import("vaxis");

pub const panic = vaxis.panic_handler;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

const App = struct {
    should_quit: bool,
    playing: bool = false,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    frame_nr: u32 = 0,
    idx: u32 = 0,
    obstacles: Obstacles,
    initial_robot: Coordinate,
    robot: Coordinate,
    initial_list: []Coordinate.Box,
    list: []Coordinate.Box,
    scratch: []Coordinate.Box,
    timer: std.time.Timer,
    directions: []const u8,
    buf: []u8,
    frame: struct {
        direction: ?aoc.Direction,
        blink: bool,
    },

    var x: u16 = undefined;
    var y: u16 = undefined;

    fn init(allocator: std.mem.Allocator, input: []const u8) !App {
        const split = std.mem.indexOf(u8, input, "\n\n") orelse return error.BadInput;
        const obstacles, const list, const robot = try parse(allocator, input[0..split]);
        const d_x, const d_y = aoc.dimensions(input[0..split]);
        x = @intCast(d_x);
        y = @intCast(d_y);
        const buf = try allocator.alloc(u8, y * (2 * x + 1));
        return .{
            .should_quit = false,
            .playing = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .frame_nr = 0,
            .obstacles = obstacles,
            .initial_robot = robot,
            .robot = robot,
            .initial_list = list,
            .list = try allocator.dupe(Coordinate.Box, list),
            .scratch = try allocator.dupe(Coordinate.Box, list),
            .timer = try std.time.Timer.start(),
            .directions = input[split + 2 ..],
            .buf = buf,
            .frame = .{
                .direction = null,
                .blink = false,
            },
        };
    }

    fn deinit(self: *App, allocator: std.mem.Allocator) void {
        self.vx.deinit(allocator, self.tty.anyWriter());
        self.tty.deinit();
        allocator.free(self.buf);
        allocator.free(self.list);
        allocator.free(self.initial_list);
        allocator.free(self.scratch);
        self.obstacles.deinit(allocator);
        self.* = undefined;
    }

    fn run(self: *App, allocator: std.mem.Allocator) !void {
        var loop: vaxis.Loop(Event) = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try loop.init();
        try loop.start();
        try self.vx.enterAltScreen(self.tty.anyWriter());
        try self.vx.queryTerminal(self.tty.anyWriter(), std.time.ns_per_s);
        while (!self.should_quit) {
            if (!self.playing) loop.pollEvent();
            while (loop.tryEvent()) |event| {
                try self.update(allocator, event);
            }
            if (self.playing and self.timer.read() > std.time.ns_per_ms * 60) {
                self.timer.reset();
                const key: vaxis.Key = .{ .codepoint = vaxis.Key.right };
                try self.update(allocator, .{ .key_press = key });
            }
            self.draw();
            var buffered = self.tty.bufferedWriter();
            try self.vx.render(buffered.writer().any());
            try buffered.flush();
            if (self.playing) std.time.sleep(std.time.ns_per_ms * 5);
        }
    }

    fn update(self: *App, allocator: std.mem.Allocator, event: Event) !void {
        switch (event) {
            .winsize => |ws| try self.vx.resize(allocator, self.tty.anyWriter(), ws),
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) self.should_quit = true;
                if (key.matches(' ', .{})) {
                    self.playing = !self.playing;
                    if (self.playing) self.timer.reset();
                }
                if (key.matches(vaxis.Key.right, .{})) {
                    if (self.idx == self.directions.len) {
                        self.playing = false;
                        return;
                    }
                    self.frame_nr +|= 1;
                    self.frame.direction = switch (self.directions[self.idx]) {
                        '^' => .north,
                        '>' => .east,
                        'v' => .south,
                        '<' => .west,
                        else => unreachable,
                    };
                    @memcpy(self.scratch, self.list);
                    if (self.robot.push(self.frame.direction.?, &self.obstacles, self.scratch, null)) {
                        self.frame.blink = false;
                        @memcpy(self.list, self.scratch);
                    } else |_| {
                        self.frame.blink = true;
                    }
                    self.idx +|= 1;
                    while (self.idx < self.directions.len and self.directions[self.idx] == '\n') self.idx +|= 1;
                }
                if (key.matches(vaxis.Key.left, .{})) {
                    self.frame_nr -|= 1;
                    self.idx -|= 1;
                    while (self.directions[self.idx] == '\n') self.idx -|= 1;
                    self.robot = self.initial_robot;
                    @memcpy(self.list, self.initial_list);
                    for (self.directions[0..self.idx]) |byte| {
                        self.frame.direction = switch (byte) {
                            '^' => .north,
                            '>' => .east,
                            'v' => .south,
                            '<' => .west,
                            '\n' => continue,
                            else => unreachable,
                        };
                        @memcpy(self.scratch, self.list);
                        if (self.robot.push(self.frame.direction.?, &self.obstacles, self.scratch, null)) {
                            self.frame.blink = false;
                            @memcpy(self.list, self.scratch);
                        } else |_| {
                            self.frame.blink = true;
                        }
                    }
                }
            },
        }
    }

    fn coordinateToOffset(coordinate: Coordinate) usize {
        const width: usize = 2 * x + 1;
        return coordinate.y * width + coordinate.x;
    }

    fn draw(self: *App) void {
        @memset(self.buf, '.');
        for (0..y) |i| self.buf[(i + 1) * (2 * x + 1) - 1] = '\n';
        for (self.obstacles.keys()) |coordinate| {
            self.buf[coordinateToOffset(coordinate)] = '#';
        }
        for (self.list) |box| {
            self.buf[coordinateToOffset(box.left)] = '[';
            self.buf[coordinateToOffset(box.right)] = ']';
        }
        self.buf[coordinateToOffset(self.robot)] = '@';
        const window = self.vx.window();
        window.clear();
        const child = window.child(.{
            .x_off = (window.width -| 2 * x) / 2,
            .y_off = (window.height -| (y + 2)) / 2,
            .width = 2 * x,
            .height = y + 2,
        });
        var iter = std.mem.tokenizeScalar(u8, self.buf, '\n');
        var row: u16 = 0;
        while (iter.next()) |line| {
            defer row += 1;
            for (line, 0..) |char, col| switch (char) {
                '#' => child.writeCell(@intCast(col), row, .{
                    .char = .{ .grapheme = "#" },
                    .style = .{ .fg = .{ .rgb = .{ 0x10, 0x20, 0x10 } } },
                }),
                '.' => child.writeCell(@intCast(col), row, .{
                    .char = .{ .grapheme = "." },
                    .style = .{ .fg = .{ .rgb = .{ 0x20, 0x10, 0x20 } } },
                }),
                '@' => child.writeCell(@intCast(col), row, .{
                    .char = .{ .grapheme = "@" },
                    .style = .{ .fg = .{ .rgb = .{ 0xee, 0x10, 0x9f } } },
                }),
                inline '[', ']' => |which| child.writeCell(@intCast(col), row, .{
                    .char = .{
                        .grapheme = if (which == '[') "[" else "]", // ] emacs shut up
                    },
                    .style = .{ .fg = .{ .rgb = .{ 0x80, 0xac, 0x20 } } },
                }),
                else => unreachable,
            };
        }
        const data = child.child(.{ .y_off = y });
        var gps: u32 = 0;
        for (self.list) |box| gps += box.left.x + (100 * box.left.y);
        var gps_buf: [32]u8 = undefined;
        const gps_text = std.fmt.bufPrint(&gps_buf, "GPS: {}", .{gps}) catch unreachable;
        _ = data.printSegment(.{
            .text = gps_text,
            .style = .{ .fg = .{ .rgb = .{ 0, 0, 0 } } },
        }, .{
            .row_offset = 0,
        });
        var frame_buf: [64]u8 = undefined;
        const frame_text = std.fmt.bufPrint(&frame_buf, "frame: {}, {s}", .{
            self.frame_nr,
            if (self.frame.direction) |d| @tagName(d) else "",
        }) catch unreachable;
        _ = data.printSegment(.{
            .text = frame_text,
            .style = if (!self.frame.blink)
                .{
                    .fg = .{ .rgb = .{ 0, 0, 0 } },
                }
            else
                .{
                    .fg = .{ .rgb = .{ 0xff, 0xff, 0xff } },
                    .bg = .{ .rgb = .{ 0, 0, 0 } },
                },
        }, .{
            .row_offset = 1,
        });
    }
};

const test_input =
    \\##########
    \\#..O..O.O#
    \\#......O.#
    \\#.OO..O.O#
    \\#..O@..O.#
    \\#O#..O...#
    \\#O..O..O.#
    \\#.OO.O.OO#
    \\#....O...#
    \\##########
    \\
    \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
    \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
    \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
    \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
    \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
    \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
    \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
    \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
    \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
    \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("15.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const is_test = is_test: {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);
        break :is_test args.len > 1 and std.mem.startsWith(u8, args[1], "test");
    };
    const input = if (!is_test) try br.reader().readAllAlloc(allocator, std.math.maxInt(usize)) else test_input;
    defer if (!is_test) allocator.free(input);

    var app = try App.init(allocator, input);
    defer app.deinit(allocator);
    try app.run(allocator);
}

const Coordinate = packed struct {
    x: u16,
    y: u16,

    const Box = struct {
        left: Coordinate,
        right: Coordinate,
    };

    fn push(self: *Coordinate, direction: aoc.Direction, obstacles: *const Obstacles, scratch: []Box, skip: ?usize) error{Obstructed}!void {
        const new: Coordinate = switch (direction) {
            .north => .{ .x = self.x, .y = self.y -| 1 },
            .east => .{ .x = self.x +| 1, .y = self.y },
            .south => .{ .x = self.x, .y = self.y +| 1 },
            .west => .{ .x = self.x -| 1, .y = self.y },
            else => unreachable,
        };
        if (new.to() == self.to()) return error.Obstructed;
        if (obstacles.get(new)) |_| return error.Obstructed;
        for (scratch, 0..) |*box, i| {
            if (skip) |j| if (i == j) continue;
            if (new.to() == box.left.to() or new.to() == box.right.to()) {
                var left = box.left;
                var right = box.right;
                try left.push(direction, obstacles, scratch, i);
                try right.push(direction, obstacles, scratch, i);
                box.* = .{ .left = left, .right = right };
            }
        }
        self.* = new;
    }

    fn to(self: Coordinate) u32 {
        return @bitCast(self);
    }
};

const Ctx = struct {
    pub fn hash(_: Ctx, a: Coordinate) u64 {
        const @"u32": u32 = @bitCast(a);
        return @"u32";
    }

    pub fn eql(_: Ctx, a: Coordinate, b: Coordinate) bool {
        return a.to() == b.to();
    }
};

const Obstacles = std.AutoArrayHashMapUnmanaged(Coordinate, void);

fn parse(allocator: std.mem.Allocator, map: []const u8) !struct { Obstacles, []Coordinate.Box, Coordinate } {
    var list: std.ArrayListUnmanaged(Coordinate.Box) = .{};
    defer list.deinit(allocator);
    var obstacles: Obstacles = .{};
    errdefer obstacles.deinit(allocator);

    var iterator = std.mem.tokenizeScalar(u8, map, '\n');
    var y: u16 = 0;
    var robot: Coordinate = undefined;
    while (iterator.next()) |line| {
        defer y += 1;
        for (line, 0..) |char, x|
            switch (char) {
                '#' => {
                    try obstacles.put(allocator, .{ .x = @intCast(2 * x), .y = y }, {});
                    try obstacles.put(allocator, .{ .x = @intCast(2 * x + 1), .y = y }, {});
                },
                '@' => robot = .{ .x = @intCast(2 * x), .y = y },
                '.' => {},
                'O' => try list.append(allocator, .{
                    .left = .{ .x = @intCast(2 * x), .y = y },
                    .right = .{ .x = @intCast(2 * x + 1), .y = y },
                }),
                else => unreachable,
            };
    }
    return .{ obstacles, try list.toOwnedSlice(allocator), robot };
}
