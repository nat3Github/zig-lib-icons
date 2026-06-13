const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core "icons" module — pure data (embedded SVG/TVG files), no deps.
    _ = b.addModule("icons", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // The demo (demo/) and the SVG->TVG converter (tools/) are now separate
    // packages with their own build.zig, so the core module stays dep-free.
}
