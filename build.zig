const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const src_dir = std.fs.cwd().openIterableDir("src", .{}) catch @panic("openIterableDir failed!");
    var walker = src_dir.walk(b.allocator) catch @panic("walking failed!");
    while (walker.next() catch @panic("walking failed!")) |entry| {
        if (std.mem.lastIndexOf(u8, entry.path, ".zig")) |idx| {
            const exe = b.addExecutable(.{
                .name = std.mem.join(
                    b.allocator,
                    "-",
                    &.{ "adventofcode", entry.path[0..idx] },
                ) catch @panic("OOM!"),
                .root_source_file = .{ .path = std.mem.join(
                    b.allocator,
                    "/",
                    &.{ "src", entry.path },
                ) catch @panic("OOM!") },
                .target = target,
                .optimize = optimize,
            });
            b.installArtifact(exe);
            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step(std.mem.join(
                b.allocator,
                "-",
                &.{ "run", entry.path[0..idx] },
            ) catch @panic("OOM!"), "Run the app");
            run_step.dependOn(&run_cmd.step);
        }
    }
}
