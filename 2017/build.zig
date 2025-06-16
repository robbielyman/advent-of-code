const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const arg = b.option([]const u8, "day", "AoC puzzle day and part in the format \"xx-xx\"").?;

    const file = b.fmt("src/{s}.zig", .{arg});
    const txt_name = arg[0..std.mem.indexOfScalar(u8, arg, '-').?];
    const input = b.fmt("{s}.txt", .{txt_name});

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path(file),
    });

    const exe = b.addExecutable(.{
        .name = arg,
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("solution", module);
    b.installArtifact(exe);

    const run_step = b.step("run", "run the specified solution");
    const run = b.addRunArtifact(exe);
    run.addArg(input);
    run_step.dependOn(&run.step);
}
