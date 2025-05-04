const std = @import("std");
pub fn build(b: *std.Build) void {
    // const step_run = b.step("run", "Run the app");
    const step_test = b.step("test", "test app");
    // const step_run_og = b.step("run-og", "Run the app");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const icons_module = b.addModule("icons", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const test1 = b.addTest(.{
        .root_module = icons_module,
    });
    b.installArtifact(test1);
    const test1_run = b.addRunArtifact(test1);
    step_test.dependOn(&test1_run.step);

    // const app_og = b.addExecutable(.{
    //     .name = "app_og",
    //     .root_source_file = b.path("src/main-og.zig"),
    //     .target = target,
    //     .optimize = optimize,
    //     .link_libc = true,
    // });
    // app_og.root_module.addImport("dvui", dvui_mod);
    // b.installArtifact(app_og);

    // const run_cmd2 = b.addRunArtifact(app_og);
    // run_cmd2.step.dependOn(b.getInstallStep());
    // step_run_og.dependOn(&run_cmd2.step);
}

test "test all refs" {
    std.testing.refAllDeclsRecursive(@This());
}
