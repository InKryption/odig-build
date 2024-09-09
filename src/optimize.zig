pub const Optimize = union(enum) {
    none,
    minimal,
    size,
    speed,
    aggressive,

    /// Other untyped but valid optimize mode.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?Optimize {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) Optimize {
        return varenum.parseEnumUnionWithOtherField(Optimize, .other, str);
    }

    pub fn asString(sanitize: Optimize) []const u8 {
        return varenum.enumUnionWithOtherFieldAsString(Optimize, .other, sanitize);
    }

    pub fn dupe(optimize: Optimize, b: *Build) Optimize {
        return switch (optimize) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(Optimize, @tagName(tag), {}),
        };
    }
};

const std = @import("std");
const Build = std.Build;

const varenum = @import("varenum.zig");
