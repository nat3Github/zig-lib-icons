const std = @import("std");
const svg2tvg = @import("svg2tvg");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;

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

fn convertSet(alloc: Allocator, io: Io, root: Dir, set: []const u8) !void {
    const svg_dir_path = try std.fmt.allocPrint(alloc, "src/svg/{s}", .{set});
    const tvg_dir_path = try std.fmt.allocPrint(alloc, "src/tvg/{s}", .{set});

    try root.createDirPath(io, tvg_dir_path);

    var svg_dir = try root.openDir(io, svg_dir_path, .{ .iterate = true });
    defer svg_dir.close(io);

    var it = svg_dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.eql(u8, ".svg", std.fs.path.extension(entry.name))) continue;

        const out_path = try std.fmt.allocPrint(alloc, "{s}/{s}.tvg", .{ tvg_dir_path, std.fs.path.stem(entry.name) });

        std.log.info("convert {s}/{s} -> {s}", .{ svg_dir_path, entry.name, out_path });

        const svg_bytes = try svg_dir.readFileAlloc(io, entry.name, alloc, .limited(4 * 1024 * 1024));
        const tvg_bytes = try svg2tvg.tvg_from_svg(alloc, svg_bytes, .{});

        try root.writeFile(io, .{ .sub_path = out_path, .data = tvg_bytes });
    }
}

fn lessThanStr(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn genEmbed(
    alloc: Allocator,
    io: Io,
    root: Dir,
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

    try root.createDirPath(io, embed_dir);

    const flat = try flattenSet(alloc, set);
    const out_path = try std.fmt.allocPrint(alloc, "{s}/{s}.zig", .{ embed_dir, flat });

    const scan_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ data_dir, set });
    var dir = try root.openDir(io, scan_path, .{ .iterate = true });
    defer dir.close(io);

    var names: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const dot_ext = try std.fmt.allocPrint(alloc, ".{s}", .{ext});
        if (!std.mem.eql(u8, dot_ext, std.fs.path.extension(entry.name))) continue;
        try names.append(alloc, try alloc.dupe(u8, std.fs.path.stem(entry.name)));
    }
    std.mem.sort([]const u8, names.items, {}, lessThanStr);

    var buf: std.ArrayList(u8) = .empty;
    for (names.items) |name| {
        const line = try std.fmt.allocPrint(
            alloc,
            "pub const @\"{s}\" = @embedFile(\"../{s}/{s}/{s}.{s}\");\n",
            .{ name, ext, set, name, ext },
        );
        try buf.appendSlice(alloc, line);
    }

    try root.writeFile(io, .{ .sub_path = out_path, .data = buf.items });
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    var threaded = Io.Threaded.init(gpa.allocator(), .{});
    defer threaded.deinit();
    const io = threaded.io();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    const root = Dir.cwd();

    for (icon_sets) |set| {
        try convertSet(alloc, io, root, set);
        try genEmbed(alloc, io, root, set, .svg);
        try genEmbed(alloc, io, root, set, .tvg);
        std.log.info("done {s}", .{set});
    }
}
