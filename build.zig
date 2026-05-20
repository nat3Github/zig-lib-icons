const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core "icons" module — pure data, no graphics deps.
    _ = b.addModule("icons", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Demo and convert steps disabled: svg2tvg pinned to zig16 branch which
    // lacks the svg2tvg_dvui module. These steps are not needed by proj-pweather.
    _ = b.step("demo", "Build the direct-render demo (disabled — svg2tvg_dvui not available on zig16 branch)");
    _ = b.step("convert", "Convert SVG icons to TVG (disabled — svg2tvg_dvui not available on zig16 branch)");
}
