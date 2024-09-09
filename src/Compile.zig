const Compile = @This();
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
timings: ?Build.LazyPath = null,
defineables: ?Build.LazyPath = null,

pub fn getArtifact(compile: *const Compile) Build.LazyPath {
    return compile.artifact;
}

pub fn getDepFile(compile: *const Compile) Build.LazyPath {
    return compile.depfile;
}

pub fn getTimings(compile: *Compile) Build.LazyPath {
    if (compile.timings) |timings| return timings;
    const maybe_ext = if (compile.options.params.export_timings) |timings_fmt| timings_fmt.asString() else null;
    const basename = compile.options.name;
    const output_name = if (maybe_ext) |ext| compile.owner.fmt("{s}.{s}", .{ basename, ext }) else basename;
    const timings = compile.run_step.addPrefixedOutputFileArg("-export-timings-file:", output_name);
    compile.timings = timings;
    return timings;
}

pub fn getDefineables(compile: *Compile) Build.LazyPath {
    if (compile.defineables) |defineables| return defineables;
    const defineables = compile.run_step.addPrefixedOutputFileArg("-export-defineables:", compile.owner.fmt("{s}.csv", .{compile.options.name}));
    compile.defineables = defineables;
    return defineables;
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

pub const Options = struct {
    odin: odig.OdinExe,
    name: []const u8,
    src: odig.Src,

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
        show_system_calls: bool = false,

        timings: ?TimingsLevel = null,
        export_timings: ?ExportTimings = null,

        show_defineables: bool = false,

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
                    bool,
                    ?TimingsLevel,
                    ?u64,
                    => {},

                    ?[]const u8,
                    => field_ptr.* = if (field_ptr.*) |str| b.dupe(str) else null,

                    ?ExportTimings,
                    ?RelocMode,
                    ?ErrorPosStyle,
                    ?Sanitize,
                    => field_ptr.* = if (field_ptr.*) |tag| tag.dupe(b) else null,

                    else => |T| @compileError("Unhandled " ++ @typeName(T)),
                }
            }
            return result;
        }

        pub fn addUnconditionalToArgs(params: Params, b: *Build, compile_run_step: *Build.Step.Run) void {
            inline for (@typeInfo(Params).@"struct".fields) |field| {
                const kebab_name = comptime comptimeReplaceScalar(u8, field.name, '_', '-');
                const field_value = @field(params, field.name);
                switch (field.type) {
                    bool => if (field_value) {
                        compile_run_step.addArg("-" ++ kebab_name);
                    },
                    ?[]const u8 => if (field_value) |str| {
                        compile_run_step.addArg(b.fmt("-" ++ kebab_name ++ ":{s}", .{str}));
                    },
                    ?u64 => if (field_value) |int| {
                        compile_run_step.addArg(b.fmt("-" ++ kebab_name ++ ":{d}", .{int}));
                    },
                    ?Optimize,
                    ?ExportTimings,
                    ?RelocMode,
                    ?ErrorPosStyle,
                    ?Sanitize,
                    => if (field_value) |tag| {
                        compile_run_step.addArg(b.fmt("-" ++ kebab_name ++ ":{s}", .{tag.asString()}));
                    },
                    ?TimingsLevel,
                    => if (field_value) |timings_level| {
                        compile_run_step.addArg(timings_level.asParamString());
                    },

                    else => |T| @compileError("Unhandled " ++ @typeName(T)),
                }
            }
        }
    };
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
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) Optimize {
        return parseEnumUnionWithOtherField(Optimize, .other, str);
    }

    pub fn asString(sanitize: Optimize) []const u8 {
        return enumUnionWithOtherFieldAsString(Optimize, .other, sanitize);
    }

    pub fn dupe(optimize: Optimize, b: *Build) Optimize {
        return switch (optimize) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(Optimize, @tagName(tag), {}),
        };
    }
};

pub const BuildMode = union(enum) {
    exe,
    shared,
    static,
    object,
    assembly,
    llvm,

    /// Other untyped but valid build mode.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?BuildMode {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) BuildMode {
        return parseEnumUnionWithOtherField(BuildMode, .other, str);
    }

    pub fn asString(sanitize: BuildMode) []const u8 {
        return enumUnionWithOtherFieldAsString(BuildMode, .other, sanitize);
    }

    pub fn dupe(build_mode: BuildMode, b: *Build) BuildMode {
        return switch (build_mode) {
            .other => |other| b.dupe(other),
            inline else => |_, tag| comptime @unionInit(BuildMode, @tagName(tag), {}),
        };
    }
};

pub const ExportTimings = union(enum) {
    json,
    csv,

    /// Other untyped but valid timings format.
    other: []const u8,

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?ExportTimings {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) ExportTimings {
        return parseEnumUnionWithOtherField(ExportTimings, .other, str);
    }

    pub fn asString(sanitize: ExportTimings) []const u8 {
        return enumUnionWithOtherFieldAsString(ExportTimings, .other, sanitize);
    }

    pub fn dupe(timings_fmt: ExportTimings, b: *Build) ExportTimings {
        return switch (timings_fmt) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(ExportTimings, @tagName(tag), {}),
        };
    }
};

pub const TimingsLevel = enum {
    show,
    @"show-more",

    pub const show_more: TimingsLevel = .@"show-more";

    pub const FromStringError = error{InvalidValue};

    pub fn asParamString(kind: TimingsLevel) []const u8 {
        return switch (kind) {
            .show => "-show-timings",
            .@"show-more" => "-show-more-timings",
        };
    }
};

pub const RelocMode = union(enum) {
    default,
    static,
    pic,
    @"dynamic-no-pic",

    /// Other untyped but valid reloc mode.
    other: []const u8,

    pub const dynamic_no_pic: RelocMode = .@"dynamic-no-pic";

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?RelocMode {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) RelocMode {
        return parseEnumUnionWithOtherField(RelocMode, .other, str);
    }

    pub fn asString(sanitize: RelocMode) []const u8 {
        return enumUnionWithOtherFieldAsString(RelocMode, .other, sanitize);
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

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?ErrorPosStyle {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) ErrorPosStyle {
        return parseEnumUnionWithOtherField(ErrorPosStyle, .other, str);
    }

    pub fn asString(sanitize: ErrorPosStyle) []const u8 {
        return enumUnionWithOtherFieldAsString(ErrorPosStyle, .other, sanitize);
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

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?Sanitize {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) Sanitize {
        return parseEnumUnionWithOtherField(Sanitize, .other, str);
    }

    pub fn asString(sanitize: Sanitize) []const u8 {
        return enumUnionWithOtherFieldAsString(Sanitize, .other, sanitize);
    }

    pub fn dupe(sanitize: Sanitize, b: *Build) Sanitize {
        return switch (sanitize) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(Sanitize, @tagName(tag), {}),
        };
    }
};

pub fn addArtifact(
    b: *Build,
    build_mode: BuildMode,
    options: Options,
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

    options.params.addUnconditionalToArgs(b, compile_run_step);

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

inline fn parseEnumUnionWithOtherField(
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

inline fn enumUnionWithOtherFieldAsString(
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

inline fn comptimeEql(
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

inline fn comptimeReplaceScalar(
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

const std = @import("std");
const Build = std.Build;

const odig = @import("../build.zig");
