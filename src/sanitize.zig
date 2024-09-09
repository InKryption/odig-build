pub const Sanitize = union(enum) {
    address,
    memory,
    thread,

    /// Other untyped but valid sanitization.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?Sanitize {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) Sanitize {
        return varenum.parseEnumUnionWithOtherField(Sanitize, .other, str);
    }

    pub fn asString(sanitize: Sanitize) []const u8 {
        return varenum.enumUnionWithOtherFieldAsString(Sanitize, .other, sanitize);
    }

    pub fn dupe(sanitize: Sanitize, b: *Build) Sanitize {
        return switch (sanitize) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(Sanitize, @tagName(tag), {}),
        };
    }
};

const std = @import("std");
const Build = std.Build;

const varenum = @import("varenum.zig");
