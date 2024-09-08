const Src = @This();
single_file: bool,
path: Build.LazyPath,

pub fn dupe(src: Src, b: *Build) Src {
    return .{
        .single_file = src.single_file,
        .path = src.path.dupe(b),
    };
}

pub fn file_path(b: *Build, path: []const u8) Src {
    return .file(b, b.path(path));
}

pub fn file(b: *Build, path: Build.LazyPath) Src {
    return .{
        .single_file = true,
        .path = path.dupe(b),
    };
}

pub fn dir_path(b: *Build, path: []const u8) Src {
    return .dir(b, b.path(path));
}

pub fn dir(b: *Build, path: Build.LazyPath) Src {
    return .{
        .single_file = false,
        .path = path.dupe(b),
    };
}

const std = @import("std");
const Build = std.Build;
