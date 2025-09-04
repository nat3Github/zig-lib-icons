const std = @import("std");
const update = @import("update_tool");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (update.updateDependencies(b, &.{
        .{
            // update tool
            .url = "https://github.com/nat3Github/zig-lib-update",
            .branch = "main",
        },
        .{
            // z2d
            .url = "https://github.com/vancluever/z2d",
            .branch = "zig-0.15.0",
        },
        .{
            // svg2tvg
            .url = "https://github.com/nat3Github/zig-lib-svg2tvg",
            .branch = "main",
        },
    })) return;

    const step_convert = b.step("convert", "convert all icon svg sets to tvg");

    const converter = b.addModule("svg", .{
        .root_source_file = b.path("src/converter.zig"),
        .target = target,
        .optimize = optimize,
    });

    const module_svg2tvg = b.dependency("svg2tvg", .{
        .target = target,
        .optimize = optimize,
    }).module("svg2tvg");

    converter.addImport("svg2tvg", module_svg2tvg);

    const tests = b.addRunArtifact(b.addTest(.{
        .root_module = converter,
    }));

    b.step("test", "Run unit tests").dependOn(&tests.step);

    const exe_converter = b.addExecutable(.{
        .name = "svg - tvg auto converter",
        .root_module = converter,
    });

    exe_converter.root_module.addImport("svg2tvg", module_svg2tvg);
    const exe_run = b.addRunArtifact(exe_converter);
    step_convert.dependOn(&exe_run.step);
}
