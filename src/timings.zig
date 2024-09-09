pub const Export = union(enum) {
    json,
    csv,

    /// Other untyped but valid timings format.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?Export {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) Export {
        return varenum.parseEnumUnionWithOtherField(Export, .other, str);
    }

    pub fn asString(sanitize: Export) []const u8 {
        return varenum.enumUnionWithOtherFieldAsString(Export, .other, sanitize);
    }

    pub fn dupe(timings_fmt: Export, b: *Build) Export {
        return switch (timings_fmt) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(Export, @tagName(tag), {}),
        };
    }
};

pub const Level = enum {
    show,
    @"show-more",

    pub const show_more: Level = .@"show-more";

    pub fn asParamString(kind: Level) []const u8 {
        return switch (kind) {
            .show => "-show-timings",
            .@"show-more" => "-show-more-timings",
        };
    }
};

const std = @import("std");
const Build = std.Build;

const varenum = @import("varenum.zig");