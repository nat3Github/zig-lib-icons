const std = @import("std");
const assert = std.debug.assert;
const expect = std.debug.expect;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;

const icons = @import("root.zig");
const Image = @import("image");
const svg2tvg = @import("svg2tvg");

/// set a debug icon to generate only the icon when testing
const debug_icon_bytes: ?[]const u8 = icons.svg.entypo.tail_spin;

const debug__ = debug_icon_bytes != null;
test "icon tiles debugging" {
    if (debug__) return;
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    // var output = std.io.getStdOut();

    const icons_n = 10;
    const icons_nxn = icons_n * icons_n;
    const icon_width = 3 * 24;
    const wh = icons_n * icon_width;

    const arr = struct {
        pub const feathericons = icons.svg.feather;
        pub const lucide = icons.svg.lucide;
        pub const entypo = icons.svg.entypo;
        pub const heroout = icons.svg.heroicons.outline;
        pub const herosol = icons.svg.heroicons.solid;
    };
    @setEvalBranchQuota(4000);
    inline for (@typeInfo(arr).@"struct".decls) |tname| {
        const T = @field(arr, tname.name);
        const idecls = @typeInfo(T).@"struct".decls;
        comptime var xtime = idecls.len / icons_nxn;
        if (comptime idecls.len % icons_nxn != 0) xtime += 1;
        inline for (0..xtime) |i| {
            const offset = i * icons_nxn;
            var img = try Image.init(alloc, wh, wh);
            inline for (idecls[offset..@min(idecls.len, offset + icons_nxn)], 0..) |decl, j| {
                const icon_bytes = @field(T, decl.name);
                try render_icon_patch(&img, alloc, icon_bytes, icons_n, j);
            }
            try img.write_ppm_to_file(try std.fmt.allocPrint(alloc, "test/{}-p{}.ppm", .{ T, i }));
            _ = arena.reset(.retain_capacity);
        }
    }
}

test "single icon debugging" {
    if (!debug__) return;
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();
    // var output = std.io.getStdOut();

    const icon_width = 24 * 10;
    const wh = icon_width;
    const svg_bytes = debug_icon_bytes.?;
    std.debug.print("{s}\n", .{svg_bytes});

    var img = try Image.init(alloc, wh, wh);

    const tvg_bytes = svg2tvg.tvg_from_svg(alloc, svg_bytes, .{}) catch |e| {
        std.log.warn("conversion error: {}", .{e});
        @panic("should not error");
    };
    defer alloc.free(tvg_bytes);

    var image_wrapper = ImageWrapper2{
        .img = &img,
        .width = @intCast(img.get_width()),
        .height = @intCast(img.get_height()),
    };

    var fb = std.io.fixedBufferStream(tvg_bytes);

    try svg2tvg.renderStream(alloc, &image_wrapper, fb.reader(), .{ .use_z2d_for_stroke = false });

    try render_icon(&img, alloc, svg_bytes);

    try img.write_ppm_to_file(try std.fmt.allocPrint(alloc, "test/{s}.ppm", .{"debug_icon"}));
}

pub const ImageWrapper2 = struct {
    width: i64,
    height: i64,
    img: *Image,
    pub fn setPixel(self: *@This(), x: i64, y: i64, color: [4]u8) void {
        const pix: Image.Pixel = .init_from_u8_slice(&color);
        self.img.set_pixel(@intCast(x), @intCast(y), pix);
    }
};
fn render_icon_patch(
    img: *Image,
    alloc: Allocator,
    svg_bytes: []const u8,
    icons_n: usize,
    index: usize,
) !void {
    assert(index < icons_n * icons_n);
    const dx = img.get_width() / icons_n;
    const yi = index / icons_n;
    const xi = index - yi * icons_n;
    var simg = img.sub_img(xi * dx, dx, yi * dx, dx);
    render_icon(&simg, alloc, svg_bytes) catch |e| {
        std.log.err("{}", .{e});
    };
}
fn render_icon(
    img: *Image,
    alloc: Allocator,
    svg_bytes: []const u8,
) !void {
    const xsvg_bytes = svg2tvg.tvg_from_svg(alloc, svg_bytes, .{}) catch |e| {
        std.log.warn("conversion error: {}", .{e});
        unreachable;
    };
    var image_wrapper = ImageWrapper2{
        .img = img,
        .width = @intCast(img.get_width()),
        .height = @intCast(img.get_height()),
    };
    var fb = std.io.fixedBufferStream(xsvg_bytes);
    try svg2tvg.renderStream(alloc, &image_wrapper, fb.reader(), .{});
}

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
        const path = try std.fmt.allocPrint(alloc, "src/svg/{s}", .{spath});
        const tvgpath = try std.fmt.allocPrint(alloc, "src/tvg/{s}", .{spath});
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
