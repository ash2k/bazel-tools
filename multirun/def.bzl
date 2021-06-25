load("@bazel_skylib//lib:shell.bzl", "shell")

_CONTENT_PREFIX = """#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \\
 source "$0.runfiles/$f" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
 { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

# Export RUNFILES_* envvars (and a couple more) for subprocesses.
runfiles_export_envvars

"""

def _multirun_impl(ctx):
    instructions_file = ctx.actions.declare_file(ctx.label.name + ".json")
    runnerInfo = ctx.attr._runner[DefaultInfo]
    runner_exe = runnerInfo.files_to_run.executable

    runfiles = ctx.runfiles(files = [instructions_file, runner_exe])
    runfiles = runfiles.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(runnerInfo.default_runfiles)

    for data_dep in ctx.attr.data:
        default_runfiles = data_dep[DefaultInfo].default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)

    commands = []
    tagged_commands = []
    runfiles_files = []
    for command in ctx.attr.commands:
        tagged_commands.append(struct(tag = str(command.label), command = command))

    for command, label in ctx.attr.tagged_commands.items():
        tagged_commands.append(struct(tag = label, command = command))

    for tag_command in tagged_commands:
        command = tag_command.command
        tag = tag_command.tag

        defaultInfo = command[DefaultInfo]
        if defaultInfo.files_to_run == None:
            fail("%s is not executable" % command.label, attr = "commands")
        exe = defaultInfo.files_to_run.executable
        if exe == None:
            fail("%s does not have an executable file" % command.label, attr = "commands")
        runfiles_files.append(exe)

        default_runfiles = defaultInfo.default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)
        commands.append(struct(
            tag = tag,
            path = exe.short_path,
        ))

    if ctx.attr.jobs < 0:
       fail("'jobs' attribute should be at least 0")

    jobs = ctx.attr.jobs
    if ctx.attr.parallel:
       print("'parallel' attribute is deprecated. Please use attribute 'jobs' instead.")
       if ctx.attr.jobs == 1:
          # If jobs is set at default value while parallel
          # is NOT set at default value, then we should respect
          # parallel to ensure backwards compatibility.
          jobs = 0
       else:
          # When both parallel and jobs are set to a non-default value,
          #   parallel == True
          #   jobs != 1
          # hard fail and ask user to only use 'jobs'.
          fail("using both 'parallel' and 'jobs' is not supported. Please use only attribute 'jobs' instead.")

    instructions = struct(
        commands = commands,
        jobs = jobs,
        quiet = ctx.attr.quiet,
        addTag = ctx.attr.add_tag,
    )
    ctx.actions.write(
        output = instructions_file,
        content = instructions.to_json(),
    )

    script = 'exec ./%s -f %s "$@"\n' % (shell.quote(runner_exe.short_path), shell.quote(instructions_file.short_path))
    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = _CONTENT_PREFIX + script,
        is_executable = True,
    )
    return [DefaultInfo(
        files = depset([out_file]),
        runfiles = runfiles.merge(ctx.runfiles(files = runfiles_files + ctx.files.data)),
        executable = out_file,
    )]

_multirun = rule(
    implementation = _multirun_impl,
    attrs = {
        "commands": attr.label_list(
            allow_empty = True,  # this is explicitly allowed - generated invocations may need to run 0 targets
            mandatory = False,
            allow_files = True,
            doc = "Targets to run",
            cfg = "target",
        ),
        "data": attr.label_list(
            doc = "The list of files needed by the commands at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes",
            allow_files = True,
        ),
        "tagged_commands": attr.label_keyed_string_dict(
            allow_empty = True,  # this is explicitly allowed - generated invocations may need to run 0 targets
            mandatory = False,
            allow_files = True,
            doc = "Labeled targets to run",
            cfg = "target",
        ),
        "jobs": attr.int(
            default = 1,
            doc = "The expected concurrency of targets to be executed. Default is set to 1 which means sequential execution. Setting to 0 means that there is no limit concurrency (same with parallel=True).",
        ),
        "parallel": attr.bool(
            default = False,
            doc = "Deprecated, please use 'jobs' instad.If true, targets will be run in parallel, not in the specified order",
        ),
        "add_tag": attr.bool(
            default = True,
            doc = "Include the tool in the output lines, only for parallel output",
        ),
        "quiet": attr.bool(
            default = False,
            doc = "Limit output where possible",
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
        "_runner": attr.label(
            default = Label("@com_github_ash2k_bazel_tools//multirun"),
            cfg = "host",
            executable = True,
        ),
    },
    executable = True,
)

def multirun(**kwargs):
    tags = kwargs.get("tags", [])
    if "manual" not in tags:
        tags.append("manual")
        kwargs["tags"] = tags
    _multirun(
        **kwargs
    )

def _command_impl(ctx):
    runfiles = ctx.runfiles().merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    for data_dep in ctx.attr.data:
        default_runfiles = data_dep[DefaultInfo].default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)

    defaultInfo = ctx.attr.command[DefaultInfo]
    executable = defaultInfo.files_to_run.executable

    default_runfiles = defaultInfo.default_runfiles
    if default_runfiles != None:
        runfiles = runfiles.merge(default_runfiles)

    expansion_targets = ctx.attr.data

    str_env = [
        "export %s=%s" % (k, shell.quote(ctx.expand_location(v, targets = expansion_targets)))
        for k, v in ctx.attr.environment.items()
    ]
    str_unqouted_env = [
        "export %s=%s" % (k, ctx.expand_location(v, targets = expansion_targets))
        for k, v in ctx.attr.raw_environment.items()
    ]
    str_args = [
        "%s" % shell.quote(ctx.expand_location(v, targets = expansion_targets))
        for v in ctx.attr.arguments
    ]
    command_exec = " ".join(["exec ./%s" % shell.quote(executable.short_path)] + str_args + ['"$@"\n'])

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([_CONTENT_PREFIX] + str_env + str_unqouted_env + [command_exec]),
        is_executable = True,
    )
    return [DefaultInfo(
        files = depset([out_file]),
        runfiles = runfiles.merge(ctx.runfiles(files = ctx.files.data + [executable])),
        executable = out_file,
    )]

_command = rule(
    implementation = _command_impl,
    attrs = {
        "arguments": attr.string_list(
            doc = "List of command line arguments. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "data": attr.label_list(
            doc = "The list of files needed by this command at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes",
            allow_files = True,
        ),
        "environment": attr.string_dict(
            doc = "Dictionary of environment variables. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "raw_environment": attr.string_dict(
            doc = "Dictionary of unqouted environment variables. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "command": attr.label(
            mandatory = True,
            allow_files = True,
            executable = True,
            doc = "Target to run",
            cfg = "target",
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    executable = True,
)

def command(**kwargs):
    tags = kwargs.get("tags", [])
    if "manual" not in tags:
        tags.append("manual")
        kwargs["tags"] = tags
    _command(
        **kwargs
    )
