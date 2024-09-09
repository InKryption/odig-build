pub inline fn parseEnumUnionWithOtherField(
    comptime U: type,
    comptime other_tag: @typeInfo(U).@"union".tag_type.?,
    str: []const u8,
) U {
    const tag = std.meta.stringToEnum(@typeInfo(U).@"union".tag_type.?, str) orelse other_tag;
    return switch (tag) {
        other_tag => @unionInit(U, @tagName(other_tag), str),
        inline else => |itag| @unionInit(U, @tagName(itag), {}),
    };
}

pub inline fn enumUnionWithOtherFieldAsString(
    comptime U: type,
    comptime other_tag: @typeInfo(U).@"union".tag_type.?,
    value: U,
) []const u8 {
    return switch (value) {
        other_tag => |other| other,
        inline else => |void_value, tag| comptime blk: {
            std.debug.assert(void_value == {});
            break :blk @tagName(tag);
        },
    };
}

const std = @import("std");
