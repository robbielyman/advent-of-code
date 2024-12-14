const std = @import("std");
const vaxis = @import("vaxis");

pub const panic = vaxis.panic_handler;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
};

const App = struct {
    should_quit: bool,
    recompute: bool = true,
    playing: bool = false,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    frame_nr: u32 = 0,
    data: []const Data,
    pos: [][2]i32,
    timer: std.time.Timer,

    fn init(allocator: std.mem.Allocator, data: []const Data, pos: [][2]i32) !App {
        return .{
            .should_quit = false,
            .tty = try vaxis.Tty.init(),
            .vx = try vaxis.init(allocator, .{}),
            .data = data,
            .pos = pos,
            .timer = try std.time.Timer.start(),
        };
    }

    fn deinit(self: *App, allocator: std.mem.Allocator) void {
        self.vx.deinit(allocator, self.tty.anyWriter());
        self.tty.deinit();
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
            if (self.playing and self.timer.read() > std.time.ns_per_ms * 300) {
                self.timer.reset();
                self.frame_nr +|= 1;
                self.recompute = true;
            }
            self.draw();
            var buffered = self.tty.bufferedWriter();
            try self.vx.render(buffered.writer().any());
            try buffered.flush();
            if (self.playing) std.time.sleep(std.time.ns_per_ms * 25);
        }
    }

    fn update(self: *App, allocator: std.mem.Allocator, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true })) self.should_quit = true;
                if (key.matches(' ', .{})) {
                    self.playing = !self.playing;
                    if (self.playing) self.timer.reset();
                }
                if (key.matches(vaxis.Key.right, .{})) {
                    self.frame_nr +|= 1;
                    self.recompute = true;
                }
                if (key.matches(vaxis.Key.left, .{})) {
                    self.frame_nr -|= 1;
                    self.recompute = true;
                }
            },
            .winsize => |ws| try self.vx.resize(allocator, self.tty.anyWriter(), ws),
        }
    }

    fn recomputePositions(self: *App) void {
        if (!self.recompute) return;
        self.recompute = false;
        const nr: i32 = @intCast(self.frame_nr);
        for (self.data, self.pos) |data, *pos| {
            pos.* = .{
                @mod(data.position[0] + data.velocity[0] * nr, width),
                @mod(data.position[1] + data.velocity[1] * nr, height),
            };
        }
    }

    const width = 101;
    const height = 103;

    fn draw(self: *App) void {
        if (self.recompute) self.recomputePositions();
        const win = self.vx.window();
        win.clear();
        const child = win.child(.{
            .x_off = (win.width -| width) / 2,
            .y_off = (win.height -| (height + 3)) / 2,
            .width = width,
            .height = height + 3,
        });

        for (self.pos) |pos| {
            child.writeCell(@intCast(pos[1]), @intCast(pos[0]), .{
                .char = .{ .grapheme = "#" },
                .style = .{ .fg = .{ .rgb = .{ 0x8a, 0xce, 0x00 } } },
            });
        }

        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrintZ(&buf, "frame number: {}", .{self.frame_nr}) catch unreachable;

        _ = child.printSegment(.{ .text = msg, .style = .{
            .fg = .{ .rgb = .{ 0x09, 0x40, 0x40 } },
        } }, .{ .row_offset = 105 });
    }
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("14.txt", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const input = try br.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    const data = try process(allocator, input);
    defer allocator.free(data);
    const pos = try allocator.alloc([2]i32, data.len);
    defer allocator.free(pos);

    var app = try App.init(allocator, data, pos);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const start_frame: u32 = if (args.len > 1) frame: {
        if (std.fmt.parseInt(u32, args[1], 10)) |frame| break :frame frame else |_| if (std.mem.eql(u8, args[1], "solve")) {
            var frame_nr: u32 = 0;
            var min: usize = std.math.maxInt(usize);
            for (0..1_000_000) |i| {
                app.frame_nr = @intCast(i);
                app.recompute = true;
                app.recomputePositions();
                const next = score(app.pos);
                if (next < min) {
                    min = next;
                    frame_nr = @intCast(i);
                }
            }
            app.recompute = true;
            break :frame frame_nr;
        } else break :frame 0;
    } else 0;

    app.frame_nr = start_frame;
    defer app.deinit(allocator);
    try app.run(allocator);
}

fn process(allocator: std.mem.Allocator, input: []const u8) ![]Data {
    var list: std.ArrayListUnmanaged(Data) = .{};
    defer list.deinit(allocator);
    var iterator = std.mem.tokenizeScalar(u8, input, '\n');
    while (iterator.next()) |line| {
        try list.append(allocator, try parse(line));
    }
    return try list.toOwnedSlice(allocator);
}

const Data = struct {
    position: struct { i32, i32 },
    velocity: struct { i32, i32 },
};

fn parse(line: []const u8) !Data {
    const comma = std.mem.indexOfScalar(u8, line, ',') orelse return error.ParseFailed;
    const p_x = try std.fmt.parseInt(i32, line[2..comma], 10);
    const space = std.mem.indexOfScalar(u8, line, ' ') orelse return error.ParseFailed;
    const p_y = try std.fmt.parseInt(i32, line[comma + 1 .. space], 10);
    const comma_2 = std.mem.indexOfScalarPos(u8, line, space, ',') orelse return error.ParseFailed;
    const v_x = try std.fmt.parseInt(i32, line[space + 3 .. comma_2], 10);
    const v_y = try std.fmt.parseInt(i32, line[comma_2 + 1 ..], 10);
    return .{
        .position = .{ p_x, p_y },
        .velocity = .{ v_x, v_y },
    };
}

fn score(positions: [][2]i32) usize {
    const mid_x = @divExact(App.width - 1, 2);
    const mid_y = @divExact(103 - 1, 2);
    var quadrants: [4]usize = .{ 0, 0, 0, 0 };
    for (positions) |pos| {
        const x, const y = pos;
        if (x < mid_x) {
            if (y < mid_y) quadrants[0] += 1;
            if (y > mid_y) quadrants[2] += 1;
        }
        if (x > mid_x) {
            if (y < mid_y) quadrants[1] += 1;
            if (y > mid_y) quadrants[3] += 1;
        }
    }
    return quadrants[0] * quadrants[1] * quadrants[2] * quadrants[3];
}
