const std = @import("std");
const update = @import("update_tool");
const deps: []const update.GitDependency = &.{
    .{
        // update tool
        .url = "https://github.com/nat3Github/zig-lib-update",
        .branch = "main",
    },
    // .{
    //     // image
    //     .url = "https://github.com/nat3Github/zig-lib-image",
    //     .branch = "main",
    // },
    // .{
    //     // z2d
    //     .url = "https://github.com/nat3Github/zig-lib-z2d-dev-fork",
    //     .branch = "main",
    // },
    // .{
    //     // svg2tvg
    //     .url = "https://github.com/nat3Github/zig-lib-svg2tvg",
    //     .branch = "main",
    // },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (update.updateDependencies(b, deps, .{
        .name = "update",
        .optimize = optimize,
        .target = target,
    })) return;

    const step_convert = b.step("convert", "convert all icon svg sets to tvg");
    const module_image = b.dependency("image", .{
        .target = target,
        .optimize = optimize,
    }).module("image");

    const converter = b.addModule("svg", .{
        .root_source_file = b.path("src/converter.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module_svg2tvg = b.dependency("svg2tvg", .{
        .target = target,
        .optimize = optimize,
    }).module("svg2tvg");

    converter.addImport("image", module_image);
    converter.addImport("svg2tvg", module_svg2tvg);

    const tests = b.addRunArtifact(b.addTest(.{
        .root_module = converter,
        .target = target,
        .optimize = optimize,
    }));

    b.step("test", "Run unit tests").dependOn(&tests.step);

    const exe_converter = b.addExecutable(.{
        .name = "svg - tvg auto converter",
        .root_module = converter,
        .optimize = optimize,
        .target = target,
    });

    exe_converter.root_module.addImport("image", module_image);
    exe_converter.root_module.addImport("svg2tvg", module_svg2tvg);
    const exe_run = b.addRunArtifact(exe_converter);
    step_convert.dependOn(&exe_run.step);
}
