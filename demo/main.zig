//! Direct-render demo: shows TVG icons rendered straight into dvui's vertex
//! pipeline (sharp at any size) next to the same icon raster-cached at a
//! small size and upscaled (blurry — what the z2d path does today).

const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");
const c = SDLBackend.c;

const icons = @import("icons");
const icons_dvui = @import("svg2tvg_dvui");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const Demo = struct {
    icon_idx: usize = 0,
    fade: f32 = 1.0,
    raster_size: i32 = 24,
    tint_r: f32 = 0.10,
    tint_g: f32 = 0.10,
    tint_b: f32 = 0.10,
};
var demo: Demo = .{};

const IconEntry = struct { name: []const u8, bytes: []const u8 };

const icon_list = [_]IconEntry{
    .{ .name = "feather: activity", .bytes = icons.tvg.feather.activity },
    .{ .name = "feather: anchor", .bytes = icons.tvg.feather.anchor },
    .{ .name = "feather: aperture", .bytes = icons.tvg.feather.aperture },
    .{ .name = "feather: alert-triangle", .bytes = icons.tvg.feather.@"alert-triangle" },
    .{ .name = "feather: archive", .bytes = icons.tvg.feather.archive },
    .{ .name = "feather: bell", .bytes = icons.tvg.feather.bell },
    .{ .name = "feather: heart", .bytes = icons.tvg.feather.heart },
    .{ .name = "feather: star", .bytes = icons.tvg.feather.star },
    .{ .name = "feather: zap", .bytes = icons.tvg.feather.zap },
    .{ .name = "lucide: activity", .bytes = icons.tvg.lucide.activity },
    .{ .name = "lucide: anchor", .bytes = icons.tvg.lucide.anchor },
    .{ .name = "entypo: rocket", .bytes = icons.tvg.entypo.rocket },
    .{ .name = "heroicons solid: bolt", .bytes = icons.tvg.heroicons.solid.bolt },
    .{ .name = "heroicons outline: heart", .bytes = icons.tvg.heroicons.outline.heart },
};

const render_sizes = [_]f32{ 16, 24, 32, 48, 64, 96, 128, 192, 256 };

pub fn main() !void {
    if (builtin.os.tag == .windows)
        dvui.Backend.Common.windowsAttachConsole() catch {};

    SDLBackend.enableSDLLogging();

    defer if (gpa_instance.deinit() != .ok) @panic("Memory leak on exit!");

    var backend = try SDLBackend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 1100.0, .h = 720.0 },
        .min_size = .{ .w = 600.0, .h = 400.0 },
        .vsync = true,
        .title = "lib-icons: direct dvui renderer demo",
    });
    defer backend.deinit();

    _ = c.SDL_EnableScreenSaver();

    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{
        .theme = switch (backend.preferredColorScheme() orelse .light) {
            .light => dvui.Theme.builtin.adwaita_light,
            .dark => dvui.Theme.builtin.adwaita_dark,
        },
    });
    defer win.deinit();

    var interrupted = false;
    main_loop: while (true) {
        const nstime = win.beginWait(interrupted);
        try win.begin(nstime);
        _ = try backend.addAllEvents(&win);

        _ = c.SDL_SetRenderDrawColor(backend.renderer, 0, 0, 0, 0);
        _ = c.SDL_RenderClear(backend.renderer);

        const keep_running = gui_frame();
        if (!keep_running) break :main_loop;

        const end_micros = try win.end(.{});
        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();

        const wait_event_micros = win.waitTime(end_micros);
        interrupted = try backend.waitEventTimeout(wait_event_micros);
    }
}

fn gui_frame() bool {
    // Top bar.
    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .style = .window,
            .background = true,
            .expand = .horizontal,
        });
        defer hbox.deinit();

        dvui.labelNoFmt(@src(), "lib-icons: direct dvui renderer vs raster-cached", .{}, .{
            .font = .theme(.title),
            .margin = .{ .x = 8, .w = 8 },
        });
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    // Controls.
    {
        var ctrl = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .margin = .all(8) });
        defer ctrl.deinit();

        var name_box = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer name_box.deinit();

        if (dvui.button(@src(), "<", .{}, .{})) {
            demo.icon_idx = (demo.icon_idx + icon_list.len - 1) % icon_list.len;
        }
        dvui.labelNoFmt(@src(), icon_list[demo.icon_idx].name, .{}, .{
            .gravity_y = 0.5,
            .margin = .{ .x = 8, .w = 8 },
            .font = .theme(.heading),
        });
        if (dvui.button(@src(), ">", .{}, .{})) {
            demo.icon_idx = (demo.icon_idx + 1) % icon_list.len;
        }

        const fade_label = std.fmt.allocPrint(dvui.currentWindow().lifo(), "AA fade: {d:.1}px", .{demo.fade}) catch "fade";
        dvui.labelNoFmt(@src(), fade_label, .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 12, .w = 4 } });
        if (dvui.button(@src(), "+", .{}, .{})) demo.fade = @min(demo.fade + 0.5, 4.0);
        if (dvui.button(@src(), "-", .{}, .{})) demo.fade = @max(demo.fade - 0.5, 0.0);

        const ras_label = std.fmt.allocPrint(dvui.currentWindow().lifo(), "raster cache size: {d}px", .{demo.raster_size}) catch "ras";
        dvui.labelNoFmt(@src(), ras_label, .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 12, .w = 4 } });
        if (dvui.button(@src(), "++", .{}, .{})) demo.raster_size = @min(demo.raster_size + 8, 128);
        if (dvui.button(@src(), "--", .{}, .{})) demo.raster_size = @max(demo.raster_size - 8, 8);
    }

    dvui.labelNoFmt(
        @src(),
        "Top row: rendered direct into dvui at each target size (resolution-independent).",
        .{},
        .{ .margin = .{ .x = 8 } },
    );
    drawRow(true);

    dvui.labelNoFmt(
        @src(),
        "Bottom row: rasterized once at the cache size, then upscaled.  This is what the z2d path does today.",
        .{},
        .{ .margin = .{ .x = 8 } },
    );
    drawRow(false);

    for (dvui.events()) |*e| {
        if (e.evt == .window and e.evt.window.action == .close) return false;
        if (e.evt == .app and e.evt.app.action == .quit) return false;
    }
    return true;
}

/// Draws the current icon at every size in `render_sizes`.  When
/// `direct` is true each icon is rendered straight into dvui at the target
/// size; otherwise the icon is rendered once into a small render-target
/// texture (`demo.raster_size` px) and that texture is drawn upscaled.
fn drawRow(direct: bool) void {
    const icon_bytes = icon_list[demo.icon_idx].bytes;
    const color = dvui.Color{
        .r = @intFromFloat(demo.tint_r * 255),
        .g = @intFromFloat(demo.tint_g * 255),
        .b = @intFromFloat(demo.tint_b * 255),
        .a = 255,
    };
    // Row discriminator: both rows share source locations, so we inject a
    // unique id_extra base to disambiguate every nested widget id.
    const row_id: u64 = if (direct) 1 else 2;

    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .id_extra = row_id,
        .expand = .horizontal,
        .margin = .{ .x = 8, .w = 8, .y = 4, .h = 12 },
    });
    defer row.deinit();

    inline for (render_sizes, 0..) |sz, i| {
        // One slot per render size: a fixed square the icon paints into.
        var slot = dvui.box(@src(), .{ .dir = .vertical }, .{
            .id_extra = row_id * 100 + i,
            .min_size_content = .{ .w = sz, .h = sz + 16 },
            .margin = .{ .x = 4, .w = 4 },
        });
        defer slot.deinit();

        const rs = slot.data().contentRectScale();
        const cell: dvui.Rect.Physical = .{
            .x = rs.r.x,
            .y = rs.r.y,
            .w = sz * rs.s,
            .h = sz * rs.s,
        };
        if (direct) {
            icons_dvui.renderTvg(dvui.currentWindow().lifo(), icon_bytes, cell, .{
                .color_override = color,
                .fade = demo.fade,
            }) catch {};
        } else {
            renderUpscaledRaster(icon_bytes, cell, color);
        }

        const size_str = std.fmt.allocPrint(dvui.currentWindow().lifo(), "{d:.0}px", .{sz}) catch "?";
        dvui.labelNoFmt(@src(), size_str, .{}, .{
            .gravity_x = 0.5,
            .id_extra = row_id * 100 + i,
        });
    }
}

/// Render the icon into a small offscreen texture at `demo.raster_size`
/// pixels, then draw that texture upscaled into `dest`.  Mimics what a
/// pre-rendered raster (z2d → image cache) looks like at large display
/// sizes: blurry / bilinear-stretched, locked to its raster resolution.
fn renderUpscaledRaster(icon_bytes: []const u8, dest: dvui.Rect.Physical, color: dvui.Color) void {
    const cache: f32 = @floatFromInt(demo.raster_size);
    const small: dvui.Rect.Physical = .{ .x = 0, .y = 0, .w = cache, .h = cache };

    // Pre-rasterize.
    var pic = dvui.Picture.start(small) orelse return;
    icons_dvui.renderTvg(dvui.currentWindow().lifo(), icon_bytes, small, .{
        .color_override = color,
        .fade = demo.fade,
    }) catch {};
    pic.stop();

    // Promote the render-target into a sampleable texture, then draw it
    // into `dest` (which may be much bigger than `cache`) — bilinear
    // upscaling is what gives the blurry look.
    const tex = dvui.textureFromTarget(pic.texture) catch return;
    dvui.textureDestroyLater(tex);

    const rs: dvui.RectScale = .{ .r = dest, .s = 1.0 };
    dvui.renderTexture(tex, rs, .{}) catch {};
    // Picture.deinit would also draw the texture at its captured rect — we
    // don't want that, so we hand-rolled the draw above and skip deinit.
    // Mark the picture struct undefined manually to avoid use-after-free
    // patterns the deinit would normally guard.
    pic.texture = undefined;
    pic.target = undefined;
    pic.r = undefined;
}
