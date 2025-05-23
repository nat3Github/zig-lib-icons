const std = @import("std");
const assert = std.debug.assert;
const expect = std.debug.expect;
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;

const icons = @import("root.zig");
const Image = @import("image");
const svg2tvg = @import("svg2tvg");

/// set a debug icon to generate only the icon when testing
const debug_icon_bytes: ?[]const u8 = icons.svg.entypo.@"tail-spin";

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

test "test2 z2d" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const z2d = svg2tvg.z2d;

    var sfc = try z2d.Surface.initPixel(.{
        .rgba = z2d.pixel.RGBA.fromClamped(1, 0, 1, 1),
    }, alloc, 256, 256);
    var ctx = z2d.Context.init(alloc, &sfc);
    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(1, 1, 1, 1) });
    try ctx.moveTo(219.00, 219.00);
    try ctx.lineTo(219.00, 219.00);
    try ctx.lineTo(217.92, 197.57);
    try ctx.lineTo(214.74, 176.75);
    try ctx.lineTo(209.58, 156.66);
    try ctx.lineTo(202.53, 137.40);
    try ctx.lineTo(193.70, 119.08);
    try ctx.lineTo(183.20, 101.79);
    try ctx.lineTo(171.13, 85.66);
    try ctx.lineTo(157.61, 70.77);
    try ctx.lineTo(142.72, 57.24);
    try ctx.lineTo(126.58, 45.17);
    try ctx.lineTo(109.30, 34.67);
    try ctx.lineTo(90.97, 25.85);
    try ctx.lineTo(71.71, 18.80);
    try ctx.lineTo(51.62, 13.63);
    try ctx.lineTo(30.81, 10.46);
    try ctx.closePath();
    try ctx.fill();
    ctx.resetPath();

    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(1, 0, 0, 1) });
    try ctx.moveTo(219.00, 219.00);
    try ctx.curveTo(
        219.00,
        103.22,
        125.16,
        9.38,
        9.38,
        9.38,
    );
    try ctx.stroke();
    ctx.resetPath();

    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(0, 1, 0, 1) });

    try z2d.png_exporter.writeToPNGFile(sfc, "test/bug2.png", .{});
}
test "test z2d" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const z2d = svg2tvg.z2d;

    var sfc = try z2d.Surface.initPixel(.{
        .rgba = z2d.pixel.RGBA.fromClamped(1, 0, 1, 1),
    }, alloc, 256, 256);
    var ctx = z2d.Context.init(alloc, &sfc);
    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(1, 1, 1, 1) });
    try ctx.moveTo(219.00, 219.00);
    try ctx.lineTo(219.00, 219.00);
    try ctx.lineTo(217.92, 197.57);
    try ctx.lineTo(214.74, 176.75);
    try ctx.lineTo(209.58, 156.66);
    try ctx.lineTo(202.53, 137.40);
    try ctx.lineTo(193.70, 119.08);
    try ctx.lineTo(183.20, 101.79);
    try ctx.lineTo(171.13, 85.66);
    try ctx.lineTo(157.61, 70.77);
    try ctx.lineTo(142.72, 57.24);
    try ctx.lineTo(126.58, 45.17);
    try ctx.lineTo(109.30, 34.67);
    try ctx.lineTo(90.97, 25.85);
    try ctx.lineTo(71.71, 18.80);
    try ctx.lineTo(51.62, 13.63);
    try ctx.lineTo(30.81, 10.46);
    try ctx.closePath();
    try ctx.fill();
    ctx.resetPath();

    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(0, 1, 0, 1) });

    try ctx.moveTo(207.28, 219.00);
    try ctx.lineTo(207.28, 219.00);
    try ctx.lineTo(207.34, 220.20);
    try ctx.lineTo(207.52, 221.36);
    try ctx.lineTo(207.81, 222.47);
    try ctx.lineTo(208.20, 223.55);
    try ctx.lineTo(208.69, 224.56);
    try ctx.lineTo(209.28, 225.52);
    try ctx.lineTo(209.95, 226.41);
    try ctx.lineTo(210.70, 227.24);
    try ctx.lineTo(211.53, 227.99);
    try ctx.lineTo(212.43, 228.65);
    try ctx.lineTo(213.39, 229.23);
    try ctx.lineTo(214.40, 229.72);
    try ctx.lineTo(215.47, 230.11);
    try ctx.lineTo(216.58, 230.39);
    try ctx.lineTo(217.73, 230.57);
    try ctx.lineTo(218.91, 230.63);
    try ctx.lineTo(220.09, 230.56);
    try ctx.lineTo(221.24, 230.39);
    try ctx.lineTo(222.35, 230.10);
    try ctx.lineTo(223.41, 229.71);
    try ctx.lineTo(224.43, 229.21);
    try ctx.lineTo(225.39, 228.63);
    try ctx.lineTo(226.28, 227.96);
    try ctx.lineTo(227.11, 227.20);
    try ctx.lineTo(227.86, 226.38);
    try ctx.lineTo(228.53, 225.48);
    try ctx.lineTo(229.12, 224.52);
    try ctx.lineTo(229.61, 223.51);
    try ctx.lineTo(230.00, 222.44);
    try ctx.lineTo(230.29, 221.33);
    try ctx.lineTo(230.47, 220.18);
    try ctx.lineTo(230.53, 219.00);
    try ctx.lineTo(230.47, 217.82);
    try ctx.lineTo(230.29, 216.67);
    try ctx.lineTo(230.00, 215.56);
    try ctx.lineTo(229.61, 214.49);
    try ctx.lineTo(229.12, 213.48);
    try ctx.lineTo(228.53, 212.52);
    try ctx.lineTo(227.86, 211.62);
    try ctx.lineTo(227.11, 210.80);
    try ctx.lineTo(226.28, 210.04);
    try ctx.lineTo(225.39, 209.37);
    try ctx.lineTo(224.43, 208.79);
    try ctx.lineTo(223.41, 208.29);
    try ctx.lineTo(222.35, 207.90);
    try ctx.lineTo(221.24, 207.61);
    try ctx.lineTo(220.09, 207.44);
    try ctx.lineTo(218.91, 207.37);
    try ctx.lineTo(217.73, 207.43);
    try ctx.lineTo(216.58, 207.61);
    try ctx.lineTo(215.47, 207.89);
    try ctx.lineTo(214.40, 208.28);
    try ctx.lineTo(213.39, 208.77);
    try ctx.lineTo(212.43, 209.35);
    try ctx.lineTo(211.53, 210.01);
    try ctx.lineTo(210.70, 210.76);
    try ctx.lineTo(209.95, 211.59);
    try ctx.lineTo(209.28, 212.48);
    try ctx.lineTo(208.69, 213.44);
    try ctx.lineTo(208.20, 214.45);
    try ctx.lineTo(207.81, 215.53);
    try ctx.lineTo(207.52, 216.64);
    try ctx.lineTo(207.34, 217.80);
    try ctx.lineTo(207.28, 219.00);
    try ctx.closePath();
    try ctx.fill();

    try z2d.png_exporter.writeToPNGFile(sfc, "test/bug.png", .{});
}

test "file bug" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const z2d = svg2tvg.z2d;

    var sfc = try z2d.Surface.initPixel(.{
        .rgba = z2d.pixel.RGBA.fromClamped(1, 0, 1, 1),
    }, alloc, 256, 256);
    var ctx = z2d.Context.init(alloc, &sfc);
    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(1, 1, 1, 1) });
    try ctx.moveTo(219.00, 219.00);
    try ctx.lineTo(30.81, 10.46);
    try ctx.stroke();
    ctx.resetPath();

    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(0, 0, 0, 1) });
    try ctx.moveTo(219.00, 219.00);
    try ctx.curveTo(
        219.00,
        103.22,
        125.16,
        9.38,
        9.38,
        9.38,
    );
    try ctx.stroke();
    ctx.resetPath();

    ctx.setSourceToPixel(.{ .rgba = z2d.pixel.RGBA.fromClamped(0, 1, 0, 1) });

    try z2d.png_exporter.writeToPNGFile(sfc, "test/file.png", .{});
}
