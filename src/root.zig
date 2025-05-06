pub const svg = struct {
    pub const feather = @import("embed-svg/feather.zig");
    pub const lucide = @import("embed-svg/lucide.zig");
    pub const heroicons = struct {
        pub const outline = @import("embed-svg/heroicons-outline.zig");
        pub const solid = @import("embed-svg/heroicons-solid.zig");
    };
};
pub const tvg = struct {
    pub const feather = @import("embed-tvg/feather.zig");
    pub const lucide = @import("embed-tvg/lucide.zig");
    pub const heroicons = struct {
        pub const outline = @import("embed-tvg/heroicons-outline.zig");
        pub const solid = @import("embed-tvg/heroicons-solid.zig");
    };
};

test "all" {
    _ = tvg.feather.activity;
    _ = svg.feather.activity;
}
