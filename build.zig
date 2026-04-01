const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const framework_dep = b.dependency("framework", .{ .target = target, .optimize = optimize });
    const framework_mod = framework_dep.module("framework");

    const exe = b.addExecutable(.{
        .name = "hermes-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{.{ .name = "framework", .module = framework_mod }},
        }),
    });
    exe.root_module.linkSystemLibrary("sqlite3", .{});
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run hermes-zig").dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{.{ .name = "framework", .module = framework_mod }},
        }),
    });
    tests.root_module.linkSystemLibrary("sqlite3", .{});
    b.step("test", "Run unit tests").dependOn(&b.addRunArtifact(tests).step);
}
