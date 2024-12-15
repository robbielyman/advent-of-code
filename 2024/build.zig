const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const day_14 = b.addExecutable(.{
        .name = "day-14-part-2",
        .root_source_file = b.path("src/14-02.zig"),
        .target = target,
        .optimize = optimize,
    });
    day_14.root_module.addImport("vaxis", vaxis.module("vaxis"));

    b.installArtifact(day_14);
    const run_day_14 = b.addRunArtifact(day_14);
    if (b.args) |args| run_day_14.addArgs(args);
    run_day_14.step.dependOn(b.getInstallStep());

    const run_14_step = b.step("run-14", "Run the app");
    run_14_step.dependOn(&run_day_14.step);

    const day_15 = b.addExecutable(.{
        .name = "day-15-part-2",
        .root_source_file = b.path("src/15-02-vaxis.zig"),
        .target = target,
        .optimize = optimize,
    });
    day_15.root_module.addImport("vaxis", vaxis.module("vaxis"));

    b.installArtifact(day_15);
    const run_day_15 = b.addRunArtifact(day_15);
    if (b.args) |args| run_day_15.addArgs(args);
    run_day_15.step.dependOn(b.getInstallStep());

    const run_15_step = b.step("run-15", "Run the app");
    run_15_step.dependOn(&run_day_15.step);
}
