const std = @import("std");
const svg2tvg = @import("svg2tvg");

const Allocator = std.mem.Allocator;

const icon_sets: []const []const u8 = &.{
    "feather",
    "heroicons/outline",
    "heroicons/solid",
    "lucide",
    "entypo",
};

fn flattenSet(alloc: Allocator, set: []const u8) ![]u8 {
    const out = try alloc.dupe(u8, set);
    for (out) |*c| if (c.* == '/') {
        c.* = '-';
    };
    return out;
}

fn convertSet(alloc: Allocator, root: std.fs.Dir, set: []const u8) !void {
    const svg_dir_path = try std.fmt.allocPrint(alloc, "src/svg/{s}", .{set});
    const tvg_dir_path = try std.fmt.allocPrint(alloc, "src/tvg/{s}", .{set});

    try root.makePath(tvg_dir_path);

    var svg_dir = try root.openDir(svg_dir_path, .{ .iterate = true });
    defer svg_dir.close();

    var it = svg_dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.eql(u8, ".svg", std.fs.path.extension(entry.name))) continue;

        const in_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ svg_dir_path, entry.name });
        const out_path = try std.fmt.allocPrint(alloc, "{s}/{s}.tvg", .{ tvg_dir_path, std.fs.path.stem(entry.name) });

        std.log.info("convert {s} -> {s}", .{ in_path, out_path });

        var in_file = try root.openFile(in_path, .{});
        defer in_file.close();
        const svg_bytes = try in_file.readToEndAlloc(alloc, 4 * 1024 * 1024);

        const tvg_bytes = try svg2tvg.tvg_from_svg(alloc, svg_bytes, .{});

        var out_file = try root.createFile(out_path, .{});
        defer out_file.close();
        try out_file.writeAll(tvg_bytes);
    }
}

fn lessThanStr(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn genEmbed(
    alloc: Allocator,
    root: std.fs.Dir,
    set: []const u8,
    kind: enum { svg, tvg },
) !void {
    const ext = switch (kind) {
        .svg => "svg",
        .tvg => "tvg",
    };
    const embed_dir = switch (kind) {
        .svg => "src/embed-svg",
        .tvg => "src/embed-tvg",
    };
    const data_dir = switch (kind) {
        .svg => "src/svg",
        .tvg => "src/tvg",
    };

    try root.makePath(embed_dir);

    const flat = try flattenSet(alloc, set);
    const out_path = try std.fmt.allocPrint(alloc, "{s}/{s}.zig", .{ embed_dir, flat });

    const scan_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ data_dir, set });
    var dir = try root.openDir(scan_path, .{ .iterate = true });
    defer dir.close();

    var names: std.ArrayList([]const u8) = .{};
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        const dot_ext = try std.fmt.allocPrint(alloc, ".{s}", .{ext});
        if (!std.mem.eql(u8, dot_ext, std.fs.path.extension(entry.name))) continue;
        try names.append(alloc, try alloc.dupe(u8, std.fs.path.stem(entry.name)));
    }
    std.mem.sort([]const u8, names.items, {}, lessThanStr);

    var out_file = try root.createFile(out_path, .{});
    defer out_file.close();
    for (names.items) |name| {
        const line = try std.fmt.allocPrint(
            alloc,
            "pub const @\"{s}\" = @embedFile(\"../{s}/{s}/{s}.{s}\");\n",
            .{ name, ext, set, name, ext },
        );
        try out_file.writeAll(line);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    var root = try std.fs.cwd().openDir(".", .{});
    defer root.close();

    for (icon_sets) |set| {
        try convertSet(alloc, root, set);
        try genEmbed(alloc, root, set, .svg);
        try genEmbed(alloc, root, set, .tvg);
        std.log.info("done {s}", .{set});
    }
}
