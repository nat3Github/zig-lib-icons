const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module_image = b.dependency("image", .{
        .target = target,
        .optimize = optimize,
    }).module("image");

    const converter = b.addModule("svg", .{
        .root_source_file = b.path("src/converter.zig"),
        .target = target,
        .optimize = optimize,
    });

    _ = b.addModule("icons", .{
        .root_source_file = b.path("src/root.zig"),
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
}
