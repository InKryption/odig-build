const OdinExe = @This();
lp: Build.LazyPath,

/// Searches for "odin" or "odin.exe" in the system path and returns it as a `cwd_relative` path.
pub fn odinInPath(b: *Build) OdinExe {
    return .inPath(b, &.{ "odin", "odin.exe" });
}

/// Searches for any program with a name matching a string in `path_or_names` and returns it as a `cwd_relative` path.
pub fn inPath(b: *Build, path_or_names: []const []const u8) OdinExe {
    const program_path = b.findProgram(path_or_names, &.{}) catch |err| @panic(@errorName(err));
    return .{ .lp = .{ .cwd_relative = program_path } };
}

/// Assumes `path` is the path of an odin compiler executable relative to the build root.
pub fn fromPath(b: *Build, path: []const u8) OdinExe {
    return .{ .lp = b.path(path) };
}

/// Assumes `lp` is the path of a generated odin compiler executable.
pub fn fromSource(b: *Build, lp: Build.LazyPath) OdinExe {
    return .{ .lp = lp.dupe(b) };
}

/// Dupes the odin executable path.
pub fn dupe(odin_exe: OdinExe, b: *Build) OdinExe {
    return .{ .lp = odin_exe.lp.dupe(b) };
}

const std = @import("std");
const Build = std.Build;
