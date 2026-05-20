// Vendored from zig-lib-svg2tvg, stripped of unused submodules.
// Source: github.com/nat3Github/zig-lib-svg2tvg

const std = @import("std");
const builtin = @import("builtin");

pub const magic_number = [2]u8{ 0x72, 0x56 };
pub const current_version = 1;

pub const parsing = @import("parsing.zig");

pub const Range = enum(u2) {
    default = 0,
    reduced = 1,
    enhanced = 2,
};

pub const ColorEncoding = enum(u2) {
    u8888 = 0,
    u565 = 1,
    f32 = 2,
    custom = 3,
};

pub const Scale = enum(u4) {
    const Self = @This();

    @"1/1" = 0,
    @"1/2" = 1,
    @"1/4" = 2,
    @"1/8" = 3,
    @"1/16" = 4,
    @"1/32" = 5,
    @"1/64" = 6,
    @"1/128" = 7,
    @"1/256" = 8,
    @"1/512" = 9,
    @"1/1024" = 10,
    @"1/2048" = 11,
    @"1/4096" = 12,
    @"1/8192" = 13,
    @"1/16384" = 14,
    @"1/32768" = 15,

    pub fn map(self: *const Self, value: f32) Unit {
        return Unit.init(self.*, value);
    }

    pub fn getShiftBits(self: *const Self) u4 {
        return @intFromEnum(self.*);
    }

    pub fn getScaleFactor(self: *const Self) u15 {
        return @as(u15, 1) << self.getShiftBits();
    }
};

pub const Unit = enum(i32) {
    const Self = @This();

    _,

    pub fn init(scale: Scale, value: f32) Self {
        return @enumFromInt(@as(i32, @intFromFloat(value * @as(f32, @floatFromInt(scale.getScaleFactor())) + 0.5)));
    }

    pub fn raw(self: *const Self) i32 {
        return @intFromEnum(self.*);
    }

    pub fn toFloat(self: *const Self, scale: Scale) f32 {
        return @as(f32, @floatFromInt(@intFromEnum(self.*))) / @as(f32, @floatFromInt(scale.getScaleFactor()));
    }

    pub fn toInt(self: *const Self, scale: Scale) i32 {
        const factor = scale.getScaleFactor();
        return @divFloor(@intFromEnum(self.*) + (@divExact(factor, 2)), factor);
    }

    pub fn toUnsignedInt(self: *const Self, scale: Scale) !u31 {
        const i = toInt(self, scale);
        if (i < 0)
            return error.InvalidData;
        return @intCast(i);
    }
};

pub const Color = extern struct {
    const Self = @This();

    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn toRgba8(self: *const Self) [4]u8 {
        return [4]u8{
            @intFromFloat(std.math.clamp(255.0 * self.r, 0.0, 255.0)),
            @intFromFloat(std.math.clamp(255.0 * self.g, 0.0, 255.0)),
            @intFromFloat(std.math.clamp(255.0 * self.b, 0.0, 255.0)),
            @intFromFloat(std.math.clamp(255.0 * self.a, 0.0, 255.0)),
        };
    }

    pub fn lerp(lhs: Self, rhs: Self, factor: f32) Self {
        const t = std.math.clamp(factor, 0, 1);
        return .{
            .r = lhs.r + (rhs.r - lhs.r) * t,
            .g = lhs.g + (rhs.g - lhs.g) * t,
            .b = lhs.b + (rhs.b - lhs.b) * t,
            .a = lhs.a + (rhs.a - lhs.a) * t,
        };
    }
};

pub const Command = enum(u6) {
    end_of_document = 0,
    fill_polygon = 1,
    fill_rectangles = 2,
    fill_path = 3,
    draw_lines = 4,
    draw_line_loop = 5,
    draw_line_strip = 6,
    draw_line_path = 7,
    outline_fill_polygon = 8,
    outline_fill_rectangles = 9,
    outline_fill_path = 10,
    _,
};

pub fn point(x: f32, y: f32) Point {
    return .{ .x = x, .y = y };
}

pub const Point = struct {
    x: f32,
    y: f32,
};

pub fn rectangle(x: f32, y: f32, width: f32, height: f32) Rectangle {
    return .{ .x = x, .y = y, .width = width, .height = height };
}

pub const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub fn line(start: Point, end: Point) Line {
    return Line{ .start = start, .end = end };
}

pub const Line = struct {
    start: Point,
    end: Point,
};

pub const Path = struct {
    segments: []Segment,

    pub const Segment = struct {
        start: Point,
        commands: []const Node,
    };

    pub const Node = union(Type) {
        const Self = @This();

        line: NodeData(Point),
        horiz: NodeData(f32),
        vert: NodeData(f32),
        bezier: NodeData(Bezier),
        arc_circle: NodeData(ArcCircle),
        arc_ellipse: NodeData(ArcEllipse),
        close: NodeData(void),
        quadratic_bezier: NodeData(QuadraticBezier),

        pub fn NodeData(comptime Payload: type) type {
            return struct {
                line_width: ?f32 = null,
                data: Payload,

                pub fn init(line_width: ?f32, data: Payload) @This() {
                    return .{ .line_width = line_width, .data = data };
                }
            };
        }

        pub const ArcCircle = struct {
            radius: f32,
            large_arc: bool,
            sweep: bool,
            target: Point,
        };

        pub const ArcEllipse = struct {
            radius_x: f32,
            radius_y: f32,
            rotation: f32,
            large_arc: bool,
            sweep: bool,
            target: Point,
        };

        pub const Bezier = struct {
            c0: Point,
            c1: Point,
            p1: Point,
        };

        pub const QuadraticBezier = struct {
            c: Point,
            p1: Point,
        };
    };

    pub const Type = enum(u3) {
        line = 0,
        horiz = 1,
        vert = 2,
        bezier = 3,
        arc_circle = 4,
        arc_ellipse = 5,
        close = 6,
        quadratic_bezier = 7,
    };
};

pub const StyleType = enum(u2) {
    flat = 0,
    linear = 1,
    radial = 2,
};

pub const Style = union(StyleType) {
    const Self = @This();

    flat: u32,
    linear: Gradient,
    radial: Gradient,
};

pub const Gradient = struct {
    point_0: Point,
    point_1: Point,
    color_0: u32,
    color_1: u32,
};

test {
    _ = parsing;
}
