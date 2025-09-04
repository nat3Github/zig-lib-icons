const std = @import("std");
const assert = std.debug.assert;
const expect = std.debug.expect;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;

const svg2tvg = @import("svg2tvg");

fn convert_all_icon_files(gpa: Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    const paths: []const []const u8 = &.{
        "feather",
        "heroicons/outline",
        "heroicons/solid",
        "lucide",
        "entypo",
    };

    for (paths) |spath| {
        const path = try std.fmt.allocPrint(alloc, "../src/svg/{s}", .{spath});
        const tvgpath = try std.fmt.allocPrint(alloc, "../src/tvg/{s}", .{spath});
        std.fs.cwd().makePath(path) catch {};
        std.fs.cwd().makePath(tvgpath) catch {};
        var dir = try std.fs.cwd().openDir(path, .{});
        defer dir.close();
        var it = dir.iterate();
        while (try it.next()) |nex| {
            if (nex.kind == .file and std.mem.eql(u8, ".svg", std.fs.path.extension(nex.name))) {
                const fpath = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ path, nex.name });
                std.log.warn("convert {s}", .{fpath});
                const opath = try std.fmt.allocPrint(alloc, "{s}/{s}.tvg", .{ tvgpath, std.fs.path.stem(nex.name) });
                std.log.warn("to {s}", .{opath});
                std.fs.cwd().makePath(std.fs.path.dirname(opath).?) catch {};

                var file = try std.fs.cwd().openFile(fpath, .{});
                defer file.close();
                var ofile = try std.fs.cwd().createFile(opath, .{});
                defer ofile.close();
                const svgb = try file.readToEndAlloc(alloc, 1024 * 1024);
                // std.log.warn("{s}", .{svgb});
                const tvgb = try svg2tvg.tvg_from_svg(alloc, svgb, .{});
                try ofile.writeAll(tvgb);
            }
        }
        _ = arena.reset(.retain_capacity);
    }
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    try convert_all_icon_files(gpa.allocator());
}
