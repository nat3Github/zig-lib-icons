# icons - TVG Icons Ready to use in Zig

- iconst are mostly in svg
- sometimes you need them in tvg (tiny vector graphics https://github.com/TinyVG/sdk)
- this lib provides the converted tvg files
- each tvg icon is embedded via @embedFile(...)
- use like: feather.@"icon-name"

# status of this library

- zig 0.14.0

# usage in dvui:
```zig
const icons = @import("icons")
```
test "convert to tvg and render" {
    const svg2tvg = @import("svg2tvg");
    const gpa = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const alloc = arena.allocator();

    const Wrapper = struct {
        width: i64,
        height: i64,
        img: *MyImage,
        pub fn setPixel(self: *@This(), x: i64, y: i64, color: [4]u8) void {
            const pix: MyPixel = .init_from_u8_slice(&color);
            self.img.set_pixel(@intCast(x), @intCast(y), pix);
        }
    };

    const width_and_height = 200;

    var myImage = try MyImageType.init(alloc, width_and_height, width_and_height);
    const my_svg_icon_data = icons.svg.feather.activity;

    var w = std.ArrayList(u8).init(alloc);
    try svg2tvg.tvg_from_svg(alloc, w.writer(), svg_bytes);

    var image_wrapper = Wrapper{
        .img = img,
        .width = @intCast(img.get_width()),
        .height = @intCast(img.get_height()),
    };

    var fb = std.io.fixedBufferStream(w.items);
    try svg2tvg.renderStream(alloc, &image_wrapper, fb.reader(), .{});

    ...
}
```

// in dvui begin: for example for feather icon lib
  icon_browser(icons.feather, ...);
// dvui end

pub fn icon_browser(T: type, rect: *dvui.Rect, open_flag: *bool) !void {
    var row_height: f32 = 30;
    var fwin = try dvui.floatingWindow(@src(), .{ .rect = rect, .open_flag = open_flag }, .{ .min_size_content = .{ .w = 300, .h = 400 } });
    defer fwin.deinit();
    try dvui.windowHeader("Icon Browser", "", open_flag);

    const decls = @typeInfo(T).@"struct".decls;
    const num_icons = decls.len;
    const height = @as(f32, @floatFromInt(num_icons)) * row_height;
    // we won't have the height the first frame, so always set it
    var scroll_info: dvui.ScrollInfo = .{ .vertical = .given };
    if (dvui.dataGet(null, fwin.wd.id, "scroll_info", dvui.ScrollInfo)) |si| {
        scroll_info = si;
        scroll_info.virtual_size.h = height;
    }
    defer dvui.dataSet(null, fwin.wd.id, "scroll_info", scroll_info);

    var scroll = try dvui.scrollArea(@src(), .{ .scroll_info = &scroll_info }, .{ .expand = .both });
    defer scroll.deinit();

    const visibleRect = scroll.si.viewport;
    var cursor: f32 = 0;
    @setEvalBranchQuota(4000);
    inline for (decls, 0..) |decl, i| {
        if (cursor <= (visibleRect.y + visibleRect.h) and (cursor + row_height) >= visibleRect.y) {
            const r = dvui.Rect{ .x = 0, .y = cursor, .w = 0, .h = row_height };
            var iconbox = try dvui.box(@src(), .horizontal, .{ .id_extra = i, .expand = .horizontal, .rect = r });

            var buf: [100]u8 = undefined;
            const text = try std.fmt.bufPrint(&buf, "{}: {s}", .{ T, decl.name });
            if (try dvui.buttonIcon(@src(), text, @field(T, decl.name), .{}, .{ .min_size_content = .{ .h = 20 } })) {}

            try dvui.labelNoFmt(@src(), text, .{ .gravity_y = 0.5 });

            iconbox.deinit();
            row_height = iconbox.wd.min_size.h;
        }

        cursor += row_height;
    }
}
```

## icon libraries included:

- feather icons https://github.com/feathericons/feather
- lucide [https://github.com/feathericons/feather](https://github.com/lucide-icons/lucide)
- heroicons https://github.com/tailwindlabs/heroicons

# Licensing

- this library: MIT
- feather: MIT
- lucide: ISC
- heroicons: MIT

# Contribution

- there is a automated shell script to convert and generate zig code
- modify it to generate the new files, modify root.zig
- i will only accept icon libraries licensed similar to MIT
