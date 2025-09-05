const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tardy = b.dependency("tardy", .{
        .target = target,
        .optimize = optimize,
    }).module("tardy");

    const bearssl, const bearssl_h = blk: {
        const bearssl = b.dependency("bearssl", .{
            .target = target,
            .optimize = optimize,
            .BR_LE_UNALIGNED = false,
            .BR_BE_UNALIGNED = false,
        });
        const bearssl_lib = bearssl.artifact("bearssl");

        const upstream = bearssl.builder.dependency("bearssl", .{
            .target = target,
            .optimize = optimize,
        });
        const c_mod = b.addTranslateC(.{
            .optimize = optimize,
            .target = target,
            .link_libc = true,
            .root_source_file = upstream.path("inc/bearssl.h"),
        }).createModule();

        break :blk .{ bearssl_lib, c_mod };
    };

    const lib = b.addModule("secsock", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibrary(bearssl);
    lib.addImport("tardy", tardy);
    lib.addImport("bearssl_h", bearssl_h);

    // add_example(b, "s2n", target, optimize, tardy, lib);
    add_example(b, "bearssl", target, optimize, tardy, lib);
}

fn add_example(
    b: *std.Build,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    tardy_module: *std.Build.Module,
    secsock_module: *std.Build.Module,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(b.fmt("examples/{s}/main.zig", .{name})),
        .target = target,
        .optimize = optimize,
        .strip = false,
        .link_libc = if (target.result.os.tag == .windows) true else false,
    });
    mod.addImport("tardy", tardy_module);
    mod.addImport("secsock", secsock_module);

    const example = b.addExecutable(.{
        .name = b.fmt("{s}", .{name}),
        .root_module = mod,
        // error: undefined symbol: tardy_swap_frame
        .use_llvm = true,
    });

    const install_artifact = b.addInstallArtifact(example, .{});
    b.getInstallStep().dependOn(&install_artifact.step);

    const build_step = b.step(b.fmt("{s}", .{name}), b.fmt("Build tardy example ({s})", .{name}));
    build_step.dependOn(&install_artifact.step);

    const run_artifact = b.addRunArtifact(example);
    run_artifact.step.dependOn(&install_artifact.step);

    const run_step = b.step(b.fmt("run_{s}", .{name}), b.fmt("Run tardy example ({s})", .{name}));
    run_step.dependOn(&install_artifact.step);
    run_step.dependOn(&run_artifact.step);
}
