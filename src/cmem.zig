pub inline fn comptimeEql(
    comptime T: type,
    comptime a: []const T,
    comptime b: []const T,
) bool {
    comptime {
        if (a.len != b.len) return false;
        const Vec = @Vector(a.len, T);
        const a_vec: Vec = a[0..].*;
        const b_vec: Vec = b[0..].*;
        return @reduce(.And, a_vec == b_vec);
    }
}

pub inline fn comptimeReplaceScalar(
    comptime T: type,
    comptime haystack: []const T,
    comptime match: T,
    comptime replacement: T,
) []const T {
    comptime {
        if (haystack.len == 0) return haystack;
        const Vec = @Vector(haystack.len, T);
        const vec: Vec = haystack[0..].*;
        const match_splat: Vec = @splat(match);
        const replace_splat: Vec = @splat(replacement);
        const replaced: [haystack.len]u8 = @select(T, vec == match_splat, replace_splat, vec);
        return &replaced;
    }
}
