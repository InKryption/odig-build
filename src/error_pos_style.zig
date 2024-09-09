pub const ErrorPosStyle = union(enum) {
    unix,
    odin,
    default,

    /// Other untyped but valid error pos style.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?ErrorPosStyle {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) ErrorPosStyle {
        return varenum.parseEnumUnionWithOtherField(ErrorPosStyle, .other, str);
    }

    pub fn asString(sanitize: ErrorPosStyle) []const u8 {
        return varenum.enumUnionWithOtherFieldAsString(ErrorPosStyle, .other, sanitize);
    }

    pub fn dupe(error_pos_style: ErrorPosStyle, b: *Build) ErrorPosStyle {
        return switch (error_pos_style) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(ErrorPosStyle, @tagName(tag), {}),
        };
    }
};

const std = @import("std");
const Build = std.Build;

const varenum = @import("varenum.zig");
