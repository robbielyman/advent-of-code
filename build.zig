const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const src_dir = try std.fs.cwd().openDir("src", .{});
    var walker = try src_dir.walk(b.allocator);
    while (try walker.next()) |entry| {
        if (std.mem.lastIndexOf(u8, entry.path, ".zig")) |idx| {
            const exe = b.addExecutable(.{
                .name = try std.mem.join(
                    b.allocator,
                    "-",
                    &.{ "adventofcode", entry.path[0..idx] },
                ),
                .root_source_file = .{
                    .path = try std.mem.join(
                        b.allocator,
                        "/",
                        &.{ "src", entry.path },
                    ),
                },
                .target = target,
                .optimize = optimize,
            });
            b.installArtifact(exe);
            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step(try std.mem.join(
                b.allocator,
                "-",
                &.{ "run", entry.path[0..idx] },
            ), "Run the app");
            run_step.dependOn(&run_cmd.step);
        }
    }
}
