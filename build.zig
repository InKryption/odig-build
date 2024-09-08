const std = @import("std");
const Build = std.Build;

pub const build = @compileError("This build.zig is intended to be imported as a direct dependency of build.zig");

pub const OdinExe = struct {
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
};

pub const Src = struct {
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
};

pub const Optimize = union(enum) {
    none,
    minimal,
    size,
    speed,
    aggressive,

    /// Other untyped but valid optimize mode.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?Optimize {
        const str = maybe_str orelse return null;
        return fromString(str);
    }

    pub fn fromString(str: []const u8) Optimize {
        const tag = std.meta.stringToEnum(@typeInfo(Optimize).@"union".tag_type.?, str) orelse .other;
        return switch (tag) {
            .other => .{ .other = str },
            inline else => |itag| @unionInit(Optimize, @tagName(itag), {}),
        };
    }

    pub fn asString(optimize: Optimize) []const u8 {
        return switch (optimize) {
            .other => |other| other,
            inline else => |void_value, tag| comptime blk: {
                std.debug.assert(void_value == {});
                break :blk snakeToKebabCase(@tagName(tag));
            },
        };
    }

    pub fn dupe(optimize: Optimize, b: *Build) Optimize {
        return switch (optimize) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(Optimize, @tagName(tag), {}),
        };
    }
};

pub fn addArtifact(
    b: *Build,
    build_mode: Compile.BuildMode,
    options: Compile.Options,
) *Compile {
    const exe_display = options.odin.lp.getDisplayName();
    const compile_run_step = Build.Step.Run.create(b, b.fmt("odin({s}) build {s} {s} -out:{s}", .{
        exe_display,
        options.src.path.getDisplayName(),
        if (options.src.single_file) "-file" else "",
        options.name,
    }));
    compile_run_step.addFileArg(options.odin.lp);
    compile_run_step.addArg("build");

    if (options.src.single_file) {
        compile_run_step.addFileArg(options.src.path);
        compile_run_step.addArg("-file");
    } else {
        compile_run_step.addDirectoryArg(options.src.path);
    }

    const exe_lp = compile_run_step.addPrefixedOutputFileArg("-out:", options.name);

    compile_run_step.addArg(b.fmt("-build-mode:{s}", .{build_mode.asString()}));

    compile_run_step.addArg("-export-dependencies:make");
    const dep_file = compile_run_step.addPrefixedDepFileOutputArg("-export-dependencies-file:", b.fmt("{s}.d", .{options.name}));

    if (options.optimize) |optimize| compile_run_step.addArg(b.fmt("-o:{s}", .{optimize.asString()}));
    if (options.target) |target| compile_run_step.addArg(b.fmt("-target:{s}", .{target}));

    options.params.addToArgs(b, compile_run_step);

    const compile = b.graph.arena.create(Compile) catch @panic("OOM");
    compile.* = .{
        .step = &compile_run_step.step,
        .owner = b,
        .run_step = compile_run_step,

        .build_mode = build_mode,
        .options = options.dupe(b),

        .artifact = exe_lp,
        .depfile = dep_file,
    };

    return compile;
}

pub fn addRunArtifact(b: *Build, compile: *const Compile) *Build.Step.Run {
    const run_step = Build.Step.Run.create(b, compile.options.name);
    run_step.addFileArg(compile.getArtifact());
    return run_step;
}

pub fn installArtifact(b: *Build, compile: *const Compile) void {
    const install_dir: Build.InstallDir = switch (compile.build_mode) {
        .exe => .bin,
        .shared => .lib,
        .static => .lib,
        .object, .assembly, .llvm, .other => @panic("object files have no standard installation procedure"),
    };
    const install_artifact = addInstallArtifactWithDir(b, compile, install_dir, null);
    b.getInstallStep().dependOn(&install_artifact.step);
}

pub fn addInstallArtifactWithDir(
    b: *Build,
    compile: *const Compile,
    install_dir: Build.InstallDir,
    maybe_des_rel_path: ?[]const u8,
) *Build.Step.InstallFile {
    return b.addInstallFileWithDir(
        compile.getArtifact(),
        install_dir,
        maybe_des_rel_path orelse compile.options.name,
    );
}

pub const Compile = struct {
    step: *Build.Step,
    owner: *Build,
    run_step: *Build.Step.Run,

    build_mode: BuildMode,
    options: Options,
    extra_linker_flags: ?usize = null,
    extra_assembler_flags: ?usize = null,
    target_features: ?usize = null,

    artifact: Build.LazyPath,
    depfile: Build.LazyPath,

    pub fn getArtifact(compile: *const Compile) Build.LazyPath {
        return compile.artifact;
    }

    pub fn getDepFile(compile: *const Compile) Build.LazyPath {
        return compile.depfile;
    }

    pub fn addDefine(compile: *const Compile, name: []const u8, value: []const u8) void {
        compile.run_step.addArg(compile.owner.fmt("-define:{s}={s}", .{ name, value }));
    }

    pub fn addCollection(compile: *const Compile, name: []const u8, lp: Build.LazyPath) void {
        compile.run_step.addPrefixedFileArg(compile.owner.fmt("-compile:{s}", .{name}), lp);
    }

    /// Any commas in `name` will be interpreted as a separator for multiple custom attributes.
    pub fn addCustomAttribute(compile: *const Compile, name: []const u8) void {
        compile.run_step.addArg(compile.owner.fmt("-custom-attribute:{s}", .{name}));
    }

    pub fn addExtraLinkerFlags(compile: *Compile, flag: []const u8) void {
        const index = compile.extra_linker_flags orelse {
            compile.extra_linker_flags = compile.run_step.argv.items.len;
            compile.run_step.addArg(compile.owner.fmt("-extra-linker-flags:\"{s}\"", .{flag}));
            return;
        };
        const str_ptr = &compile.run_step.argv.items[index].bytes;
        str_ptr.* = std.mem.concat(compile.owner.graph.arena, u8, &.{ str_ptr.*[0 .. str_ptr.len - 1], ",", flag }) catch @panic("OOM");
    }

    pub fn addExtraAssemblerFlag(compile: *const Compile, flag: []const u8) void {
        const index = compile.extra_assembler_flags orelse {
            compile.extra_assembler_flags = compile.run_step.argv.items.len;
            compile.run_step.addArg(compile.owner.fmt("-extra-assembler-flags:\"{s}\"", .{flag}));
            return;
        };
        const str_ptr = &compile.run_step.argv.items[index].bytes;
        str_ptr.* = std.mem.concat(compile.owner.graph.arena, u8, &.{ str_ptr.*[0 .. str_ptr.len - 1], ",", flag }) catch @panic("OOM");
    }

    pub fn addTargetFeature(compile: *const Compile, flag: []const u8) void {
        const index = compile.extra_assembler_flags orelse {
            compile.extra_assembler_flags = compile.run_step.argv.items.len;
            compile.run_step.addArg(compile.owner.fmt("-target-features:\"{s}\"", .{flag}));
            return;
        };
        const str_ptr = &compile.run_step.argv.items[index].bytes;
        str_ptr.* = std.mem.concat(compile.owner.graph.arena, u8, &.{ str_ptr.*[0 .. str_ptr.len - 1], ",", flag }) catch @panic("OOM");
    }

    pub const BuildMode = union(enum) {
        exe,
        shared,
        static,
        object,
        assembly,
        llvm,

        /// Other untyped but valid build mode.
        other: []const u8,

        pub fn asString(build_mode: BuildMode) []const u8 {
            return switch (build_mode) {
                .other => |other| other,
                inline else => |void_value, tag| comptime blk: {
                    std.debug.assert(void_value == {});
                    break :blk snakeToKebabCase(@tagName(tag));
                },
            };
        }

        pub fn dupe(build_mode: BuildMode, b: *Build) BuildMode {
            return switch (build_mode) {
                .other => |other| b.dupe(other),
                inline else => |_, tag| comptime @unionInit(BuildMode, @tagName(tag), {}),
            };
        }
    };

    pub const RelocMode = union(enum) {
        default,
        static,
        pic,
        dynamic_no_pic,

        /// Other untyped but valid reloc mode.
        other: []const u8,

        pub fn asString(reloc_mode: RelocMode) []const u8 {
            return switch (reloc_mode) {
                .other => |other| other,
                inline else => |void_value, tag| comptime blk: {
                    std.debug.assert(void_value == {});
                    break :blk snakeToKebabCase(@tagName(tag));
                },
            };
        }

        pub fn dupe(reloc_mode: RelocMode, b: *Build) RelocMode {
            return switch (reloc_mode) {
                .other => |other| .{ .other = b.dupe(other) },
                inline else => |_, tag| comptime @unionInit(RelocMode, @tagName(tag), {}),
            };
        }
    };

    pub const ErrorPosStyle = union(enum) {
        unix,
        odin,
        default,

        /// Other untyped but valid error pos style.
        other: []const u8,

        pub fn asString(error_pos_style: ErrorPosStyle) []const u8 {
            return switch (error_pos_style) {
                .other => |other| other,
                inline else => |void_value, tag| comptime blk: {
                    std.debug.assert(void_value == {});
                    break :blk snakeToKebabCase(@tagName(tag));
                },
            };
        }

        pub fn dupe(error_pos_style: ErrorPosStyle, b: *Build) ErrorPosStyle {
            return switch (error_pos_style) {
                .other => |other| .{ .other = b.dupe(other) },
                inline else => |_, tag| comptime @unionInit(ErrorPosStyle, @tagName(tag), {}),
            };
        }
    };

    pub const Sanitize = union(enum) {
        address,
        memory,
        thread,

        /// Other untyped but valid sanitization.
        other: []const u8,

        pub fn asString(sanitize: Sanitize) []const u8 {
            return switch (sanitize) {
                .other => |other| other,
                inline else => |void_value, tag| comptime blk: {
                    std.debug.assert(void_value == {});
                    break :blk snakeToKebabCase(@tagName(tag));
                },
            };
        }

        pub fn dupe(sanitize: Sanitize, b: *Build) Sanitize {
            return switch (sanitize) {
                .other => |other| .{ .other = b.dupe(other) },
                inline else => |_, tag| comptime @unionInit(Sanitize, @tagName(tag), {}),
            };
        }
    };

    pub const Options = struct {
        odin: OdinExe,
        name: []const u8,
        src: Src,

        optimize: ?Optimize = null,
        target: ?[]const u8 = null,

        params: Params = .{},

        pub fn dupe(options: Options, b: *Build) Options {
            return .{
                .odin = options.odin.dupe(b),
                .name = b.dupe(options.name),
                .src = options.src.dupe(b),

                .optimize = if (options.optimize) |optimize| optimize.dupe(b) else null,
                .target = if (options.target) |target| b.dupe(target) else null,

                .params = options.params.dupe(b),
            };
        }

        pub const Params = struct {
            thread_count: ?u64 = null,
            debug: bool = false,
            disable_assert: bool = false,
            no_bounds_check: bool = false,
            no_type_assert: bool = false,
            no_crt: bool = false,
            no_thread_local: bool = false,
            lld: bool = false,
            use_separate_modules: bool = false,
            no_threaded_checker: bool = false,

            vet: bool = false,
            vet_unused: bool = false,
            vet_unused_variables: bool = false,
            vet_unused_imports: bool = false,
            vet_shadowing: bool = false,
            vet_using_stmt: bool = false,
            vet_using_param: bool = false,
            vet_style: bool = false,
            vet_semicolon: bool = false,
            vet_cast: bool = false,
            vet_tabs: bool = false,

            ignore_unknown_attributes: bool = false,

            no_entry_point: bool = false,
            minimum_os_version: ?[]const u8 = null,
            microarch: ?[]const u8 = null,
            strict_target_features: bool = false,
            reloc_mode: ?RelocMode = null,
            disable_red_zone: bool = false,
            dynamic_map_calls: bool = false,
            print_linker_flags: bool = false,

            disallow_do: bool = false,
            default_to_nil_allocator: bool = false,
            strict_style: bool = false,

            ignore_warnings: bool = false,
            warnings_as_errors: bool = false,
            terse_errors: bool = false,
            json_errors: bool = false,
            error_pos_style: ?ErrorPosStyle = null,
            max_error_count: ?u64 = null,

            min_link_libs: bool = false,
            foreign_error_procedures: bool = false,
            obfuscate_source_code_locations: bool = false,
            sanitize: ?Sanitize = null,

            pub fn dupe(params: Params, b: *Build) Params {
                var result = params;
                inline for (@typeInfo(Compile.Options.Params).@"struct".fields) |field| {
                    const field_ptr = &@field(result, field.name);
                    switch (field.type) {
                        bool => {},
                        ?[]const u8 => field_ptr.* = if (field_ptr.*) |str| b.dupe(str) else null,
                        ?u64 => {},
                        ?RelocMode,
                        ?ErrorPosStyle,
                        ?Sanitize,
                        => field_ptr.* = if (field_ptr.*) |tag| tag.dupe(b) else null,

                        else => |T| @compileError("Unhandled " ++ @typeName(T)),
                    }
                }
                return result;
            }

            pub fn addToArgs(params: Params, b: *Build, compile_run_step: *Build.Step.Run) void {
                inline for (@typeInfo(Compile.Options.Params).@"struct".fields) |field| {
                    const field_value = @field(params, field.name);
                    switch (field.type) {
                        bool => if (field_value) {
                            compile_run_step.addArg("-" ++ snakeToKebabCase(field.name));
                        },
                        ?[]const u8 => if (field_value) |str| {
                            compile_run_step.addArg(b.fmt("-" ++ snakeToKebabCase(field.name) ++ ":{s}", .{str}));
                        },
                        ?u64 => if (field_value) |int| {
                            compile_run_step.addArg(b.fmt("-" ++ snakeToKebabCase(field.name) ++ ":{d}", .{int}));
                        },
                        ?Optimize,
                        ?RelocMode,
                        ?ErrorPosStyle,
                        ?Sanitize,
                        => if (field_value) |tag| {
                            compile_run_step.addArg(b.fmt("-" ++ snakeToKebabCase(field.name) ++ ":{d}", .{tag.asString()}));
                        },

                        else => |T| @compileError("Unhandled " ++ @typeName(T)),
                    }
                }
            }
        };
    };
};

inline fn snakeToKebabCase(comptime str: []const u8) []const u8 {
    comptime {
        var result = str[0..].*;
        std.mem.replaceScalar(u8, &result, '_', '-');
        const copy = result;
        return &copy;
    }
}
