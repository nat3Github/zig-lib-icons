const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core "icons" module — pure data, no graphics deps.
    const icons_mod = b.addModule("icons", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Demo: small SDL3 + dvui app showing the direct renderer at multiple
    // sizes. `zig build demo -- run` to build & run. Lazy: only fetches
    // dvui and svg2tvg when this step is requested.
    const demo_step = b.step("demo", "Build the direct-render demo (SDL3 + dvui)");

    if (b.lazyDependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
    })) |dvui_dep| if (b.lazyDependency("svg2tvg", .{
        .target = target,
        .optimize = optimize,
    })) |svg2tvg_dep| {
        const dvui_mod = dvui_dep.module("dvui_sdl3");
        const sdl_mod = dvui_dep.module("sdl3");

        // Renderer lives in svg2tvg's `svg2tvg_dvui` module on branch
        // `dvui-render`. Inject our dvui module so the renderer compiles
        // against the same dvui the demo links.
        const svg2tvg_dvui_mod = svg2tvg_dep.module("svg2tvg_dvui");
        svg2tvg_dvui_mod.addImport("dvui", dvui_mod);

        const exe = b.addExecutable(.{
            .name = "icons-demo",
            .root_module = b.createModule(.{
                .root_source_file = b.path("demo/main.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("dvui", dvui_mod);
        exe.root_module.addImport("sdl-backend", sdl_mod);
        exe.root_module.addImport("icons", icons_mod);
        exe.root_module.addImport("svg2tvg_dvui", svg2tvg_dvui_mod);

        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        if (b.args) |args| run.addArgs(args);
        demo_step.dependOn(&run.step);
    };

    // `zig build convert` — rebuild all TVG files from SVG and regenerate
    // the embed-svg / embed-tvg zig sources. Replaces converter/sh/run.sh.
    // Lazy: svg2tvg only fetched when this step is requested.
    const convert_step = b.step("convert", "Convert all SVG icon sets to TVG and regenerate embed-*.zig sources");
    if (b.lazyDependency("svg2tvg", .{
        .target = target,
        .optimize = optimize,
    })) |svg2tvg_dep| {
        const tool_mod = b.createModule(.{
            .root_source_file = b.path("tools/convert.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        });
        tool_mod.addImport("svg2tvg", svg2tvg_dep.module("svg2tvg"));

        const tool_exe = b.addExecutable(.{
            .name = "icons-convert",
            .root_module = tool_mod,
        });
        const tool_run = b.addRunArtifact(tool_exe);
        // Run from repo root so relative `src/svg/...` paths resolve.
        tool_run.setCwd(b.path("."));
        convert_step.dependOn(&tool_run.step);
    }
}
