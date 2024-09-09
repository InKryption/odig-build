const Check = @This();

step: *Build.Step,
owner: *Build,
run_step: *Build.Step.Run,

options: Options,

extra_linker_flags: ?usize = null,
extra_assembler_flags: ?usize = null,
target_features: ?usize = null,

depfile: Build.LazyPath,
timings: ?Build.LazyPath = null,
defineables: ?Build.LazyPath = null,

pub fn getDepFile(check: *const Check) Build.LazyPath {
    return check.depfile;
}

pub fn getTimings(check: *Check) Build.LazyPath {
    if (check.timings) |timings| return timings;
    const maybe_ext = if (check.options.export_timings) |timings_fmt| timings_fmt.asString() else null;
    const basename = check.options.name;
    const output_name = if (maybe_ext) |ext| check.owner.fmt("{s}.{s}", .{ basename, ext }) else basename;
    const timings = check.run_step.addPrefixedOutputFileArg("-export-timings-file:", output_name);
    check.timings = timings;
    return timings;
}

pub fn getDefineables(check: *Check) Build.LazyPath {
    if (check.defineables) |defineables| return defineables;
    const defineables = check.run_step.addPrefixedOutputFileArg("-export-defineables:", check.owner.fmt("{s}.csv", .{check.options.name}));
    check.defineables = defineables;
    return defineables;
}

pub fn addDefine(check: *const Check, name: []const u8, value: []const u8) void {
    check.run_step.addArg(check.owner.fmt("-define:{s}={s}", .{ name, value }));
}

pub fn addCollection(check: *const Check, name: []const u8, lp: Build.LazyPath) void {
    check.run_step.addPrefixedFileArg(check.owner.fmt("-check:{s}", .{name}), lp);
}

/// Any commas in `name` will be interpreted as a separator for multiple custom attributes.
pub fn addCustomAttribute(check: *const Check, name: []const u8) void {
    check.run_step.addArg(check.owner.fmt("-custom-attribute:{s}", .{name}));
}

pub const Options = struct {
    odin: odig.OdinExe,
    name: ?[]const u8 = null,
    src: odig.Src,

    target: ?[]const u8 = null,

    show_system_calls: bool = false,

    timings: ?odig.timings.Level = null,
    export_timings: ?odig.timings.Export = null,

    show_defineables: bool = false,

    thread_count: ?u64 = null,
    no_threaded_checker: bool = false,

    show_unused: bool = false,
    show_unused_with_location: bool = false,

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
            comptime if (cmem.comptimeEql(u8, field.name, @tagName(FieldTag.target))) continue;

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
                ?odig.ErrorPosStyle,
                => if (field_value) |tag| {
                    compile_run_step.addArg(b.fmt("-" ++ kebab_name ++ ":{s}", .{tag.asString()}));
                },
                ?odig.timings.Level,
                => if (field_value) |timings_level| {
                    compile_run_step.addArg(timings_level.asParamString());
                },

                else => |T| @compileError("Unhandled " ++ @typeName(T)),
            }
        }
    }
};

pub fn addArtifact(
    b: *Build,
    options: Options,
) *Check {
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

    compile_run_step.addArg("-export-dependencies:make");
    const dep_file = compile_run_step.addPrefixedDepFileOutputArg("-export-dependencies-file:", b.fmt("{s}.d", .{options.name}));

    if (options.optimize) |optimize| compile_run_step.addArg(b.fmt("-o:{s}", .{optimize.asString()}));

    options.addUnconditionalToArgs(b, compile_run_step);

    const compile = b.graph.arena.create(Check) catch @panic("OOM");
    compile.* = .{
        .step = &compile_run_step.step,
        .owner = b,
        .run_step = compile_run_step,

        .options = options.dupe(b),

        .depfile = dep_file,
    };

    return compile;
}

const std = @import("std");
const Build = std.Build;

const odig = @import("../build.zig");
const cmem = @import("cmem.zig");
