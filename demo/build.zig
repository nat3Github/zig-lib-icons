const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core data module (path dependency on the parent icons package).
    const icons_dep = b.dependency("icons", .{
        .target = target,
        .optimize = optimize,
    });
    const icons_mod = icons_dep.module("icons");

    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .sdl3,
    });
    const svg2tvg_dep = b.dependency("svg2tvg", .{
        .target = target,
        .optimize = optimize,
    });

    const dvui_mod = dvui_dep.module("dvui_sdl3");
    const sdl_mod = dvui_dep.module("sdl3");

    // Renderer lives in svg2tvg's `svg2tvg_dvui` module. Inject our dvui
    // module so the renderer compiles against the same dvui the demo links.
    const svg2tvg_dvui_mod = svg2tvg_dep.module("svg2tvg_dvui");
    svg2tvg_dvui_mod.addImport("dvui", dvui_mod);

    const exe = b.addExecutable(.{
        .name = "icons-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
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
    const run_step = b.step("run", "Build & run the direct-render demo (SDL3 + dvui)");
    run_step.dependOn(&run.step);
}
