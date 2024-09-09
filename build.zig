pub const build = @compileError("This build.zig is intended to be imported as a direct dependency of build.zig");

pub const OdinExe = @import("src/OdinExe.zig");

pub const Optimize = @import("src/optimize.zig").Optimize;
pub const timings = @import("src/timings.zig");
pub const ErrorPosStyle = @import("src/error_pos_style.zig").ErrorPosStyle;
pub const Sanitize = @import("src/sanitize.zig").Sanitize;

pub const Src = @import("src/Src.zig");

pub const Compile = @import("src/Compile.zig");

pub const addArtifact = Compile.addArtifact;
pub const addRunArtifact = Compile.addRunArtifact;
pub const installArtifact = Compile.installArtifact;
pub const addInstallArtifactWithDir = Compile.addInstallArtifactWithDir;

const std = @import("std");
const Build = std.Build;
