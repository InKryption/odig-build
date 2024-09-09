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
    const maybe_ext = if (compile.options.export_timings) |timings_fmt| timings_fmt.asString() else null;
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

pub fn addSanitize(compile: *const Compile, sanitize: odig.Sanitize) void {
    compile.run_step.addArg(compile.owner.fmt("-sanitize:{s}", .{sanitize.asString()}));
}

pub const Options = struct {
    odin: odig.OdinExe,
    name: []const u8,
    src: odig.Src,

    optimize: ?odig.Optimize = null,
    target: ?[]const u8 = null,

    show_system_calls: bool = false,

    timings: ?odig.timings.Level = null,
    export_timings: ?odig.timings.Export = null,

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
    error_pos_style: ?odig.ErrorPosStyle = null,
    max_error_count: ?u64 = null,

    min_link_libs: bool = false,
    foreign_error_procedures: bool = false,
    obfuscate_source_code_locations: bool = false,

    pub fn dupe(options: Options, b: *Build) Options {
        var result = options;
        inline for (@typeInfo(Options).@"struct".fields) |field| {
            const field_ptr = &@field(result, field.name);
            switch (field.type) {
                ?odig.Optimize,
                ?odig.timings.Level,
                bool,
                ?u64,
                => {},

                odig.OdinExe,
                odig.Src,
                => field_ptr.* = field_ptr.dupe(b),

                []const u8,
                => field_ptr.* = b.dupe(field_ptr.*),
                ?[]const u8,
                => field_ptr.* = if (field_ptr.*) |str| b.dupe(str) else null,

                ?odig.timings.Export,
                ?RelocMode,
                ?odig.ErrorPosStyle,
                => field_ptr.* = if (field_ptr.*) |tag| tag.dupe(b) else null,

                else => |T| @compileError("Unhandled " ++ @typeName(T)),
            }
        }
        return result;
    }

    pub fn addUnconditionalToArgs(options: Options, b: *Build, compile_run_step: *Build.Step.Run) void {
        const FieldTag = std.meta.FieldEnum(Options);
        inline for (@typeInfo(Options).@"struct".fields) |field| {
            comptime if (cmem.comptimeEql(u8, field.name, @tagName(FieldTag.odin))) continue;
            comptime if (cmem.comptimeEql(u8, field.name, @tagName(FieldTag.name))) continue;
            comptime if (cmem.comptimeEql(u8, field.name, @tagName(FieldTag.src))) continue;
            comptime if (cmem.comptimeEql(u8, field.name, @tagName(FieldTag.optimize))) continue;

            const kebab_name = comptime cmem.comptimeReplaceScalar(u8, field.name, '_', '-');
            const field_value = @field(options, field.name);
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
                ?odig.timings.Export,
                ?RelocMode,
                ?odig.ErrorPosStyle,
                ?odig.Sanitize,
                => if (field_value) |tag| {
                    compile_run_step.addArg(b.fmt("-" ++ kebab_name ++ ":{s}", .{tag.asString()}));
                },
                ?odig.timings.Level,
                => if (field_value) |timings_level| {
                    compile_run_step.addArg(timings_level.asParamString());
                },

                ?odig.Optimize => unreachable,
                else => |T| @compileError("Unhandled " ++ @typeName(T)),
            }
        }
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
        return varenum.parseEnumUnionWithOtherField(BuildMode, .other, str);
    }

    pub fn asString(sanitize: BuildMode) []const u8 {
        return varenum.enumUnionWithOtherFieldAsString(BuildMode, .other, sanitize);
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
    @"dynamic-no-pic",

    /// Other untyped but valid reloc mode.
    other: []const u8,

    pub const dynamic_no_pic: RelocMode = .@"dynamic-no-pic";

    pub fn fromStringOpt(maybe_str: ?[]const u8) ?RelocMode {
        return fromString(maybe_str orelse return null);
    }

    pub fn fromString(str: []const u8) RelocMode {
        return varenum.parseEnumUnionWithOtherField(RelocMode, .other, str);
    }

    pub fn asString(sanitize: RelocMode) []const u8 {
        return varenum.enumUnionWithOtherFieldAsString(RelocMode, .other, sanitize);
    }

    pub fn dupe(reloc_mode: RelocMode, b: *Build) RelocMode {
        return switch (reloc_mode) {
            .other => |other| .{ .other = b.dupe(other) },
            inline else => |_, tag| comptime @unionInit(RelocMode, @tagName(tag), {}),
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

    options.addUnconditionalToArgs(b, compile_run_step);

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

const std = @import("std");
const Build = std.Build;

const odig = @import("../build.zig");
const varenum = @import("varenum.zig");
const cmem = @import("cmem.zig");
