const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const svg2tvg_dep = b.dependency("svg2tvg", .{
        .target = b.graph.host,
        .optimize = optimize,
    });

    const tool_mod = b.createModule(.{
        .root_source_file = b.path("convert.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    tool_mod.addImport("svg2tvg", svg2tvg_dep.module("svg2tvg"));

    const tool_exe = b.addExecutable(.{
        .name = "icons-convert",
        .root_module = tool_mod,
    });

    const run = b.addRunArtifact(tool_exe);
    // Run from the icons repo root (parent dir) so the relative
    // `src/svg/...` / `src/tvg/...` paths resolve.
    run.setCwd(b.path(".."));

    const convert_step = b.step("convert", "Convert all SVG icon sets to TVG and regenerate embed-*.zig sources");
    convert_step.dependOn(&run.step);
    b.default_step = convert_step;
}
