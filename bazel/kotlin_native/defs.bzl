"""Homemade Bazel rules for Kotlin/Native: klibs, Apple frameworks, and tests in an iOS simulator.

No released Bazel rules build Kotlin/Native, so the solution C prototype writes its own. They run
`bin/konanc` of the distribution that MODULE.bazel downloads, on an Apple silicon Mac only. Give
their targets `target_compatible_with = KOTLIN_NATIVE_COMPATIBLE_WITH`: other hosts skip them.

    kt_native_library      Kotlin sources -> one klib per Kotlin/Native target
    kt_native_test         tests -> an executable, run in an iOS simulator by `bazel test`
    kt_native_framework    klibs -> a static Apple framework, for one Kotlin/Native target
    kt_native_xcframework  frameworks of every target -> an XCFramework, for Swift packages
    kt_native_import       downloaded klibs: the repository @klibs is made of them

Kotlin/Native targets are fixed in targets.bzl, and every library is built for each of them.
"""

load("@rules_java//java/common:java_common.bzl", "java_common")
load(":providers.bzl", "KotlinNativeFrameworkInfo", "KotlinNativeInfo", "KotlinNativeToolchainInfo")
load(":targets.bzl", "KOTLIN_NATIVE_TARGETS", "KOTLIN_NATIVE_TEST_TARGET")

# The Mac that runs the compiler, and the iOS targets of the application. Other hosts skip the targets.
KOTLIN_NATIVE_COMPATIBLE_WITH = select({
    Label("@platforms//os:macos"): [],
    Label("@platforms//os:ios"): [],
    "//conditions:default": [Label("@platforms//:incompatible")],
})

_COMPILER_ATTRS = {
    "_java_runtime": attr.label(
        default = Label("@rules_java//toolchains:current_java_runtime"),
        cfg = "exec",
    ),
    "_toolchain": attr.label(
        default = Label("@kotlin_native//:toolchain"),
        providers = [KotlinNativeToolchainInfo],
    ),
    "_xcode_config": attr.label(
        default = Label("@apple_support//xcode:version_config"),
    ),
}

def _toolchain(ctx):
    toolchain = ctx.attr._toolchain[KotlinNativeToolchainInfo]
    if not toolchain.supported:
        fail("{} needs the Kotlin/Native compiler, which runs on an Apple silicon Mac only. This host is {}.".format(
            ctx.label,
            toolchain.host,
        ))
    return toolchain

def _without_extension(path, extension):
    if not path.endswith(extension):
        fail("{} does not end with {}".format(path, extension))
    return path[:-len(extension)]

def _xcode_execution_requirements(xcode_config):
    requirements = dict(xcode_config.execution_info())

    # The compiler locks a file of its data directory, which a sandbox would make read-only. Xcode
    # tools and the simulator also keep state in the user's home directory.
    requirements["no-sandbox"] = "1"
    return requirements

def _compiler_arguments(ctx, target):
    """Arguments of every compiler run, written to a parameter file."""
    toolchain = _toolchain(ctx)
    arguments = ctx.actions.args()
    arguments.use_param_file("@%s", use_always = True)
    arguments.set_param_file_format("multiline")
    arguments.add("-target", target)

    # LLVM and libffi come from the repository: the compiler must never download them.
    arguments.add("-Xkonan-data-dir=" + toolchain.data)
    arguments.add("-Xoverride-konan-properties=airplaneMode=true")
    return arguments

def _run_compiler(ctx, *, target, arguments, inputs, outputs, mnemonic, progress_message):
    toolchain = _toolchain(ctx)
    java_runtime = ctx.attr._java_runtime[java_common.JavaRuntimeInfo]
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    # XCODE_VERSION_OVERRIDE: Bazel sets DEVELOPER_DIR to that Xcode, which the compiler finds
    # with xcrun. JAVA_HOME: bin/konanc runs on the JDK of Bazel.
    env = dict(apple_common.apple_host_system_env(xcode_config))
    env["JAVA_HOME"] = java_runtime.java_home
    env["KONAN_DATA_DIR"] = toolchain.data

    ctx.actions.run(
        executable = toolchain.konanc,
        arguments = [arguments],
        inputs = depset(
            transitive = [
                inputs,
                toolchain.files,
                toolchain.target_files[target],
                java_runtime.files,
            ],
        ),
        outputs = outputs,
        env = env,
        use_default_shell_env = True,
        execution_requirements = _xcode_execution_requirements(xcode_config),
        mnemonic = mnemonic,
        progress_message = progress_message,
    )

def _module_name(ctx):
    # Unique among every klib of a binary: shared/feature/login gives shared-feature-login.
    return ctx.attr.module_name or ctx.label.package.replace("/", "-")

def _dependency_klibs(infos, target):
    return depset(transitive = [info.transitive_klibs[target] for info in infos])

# --- kt_native_library ---

def _kt_native_library_impl(ctx):
    deps = [dep[KotlinNativeInfo] for dep in ctx.attr.deps]
    module_name = _module_name(ctx)
    klibs = {}
    transitive_klibs = {}
    for target in KOTLIN_NATIVE_TARGETS:
        dependencies = _dependency_klibs(deps, target)
        klib = ctx.actions.declare_file("{}/{}/{}.klib".format(ctx.label.name, target, module_name))

        arguments = _compiler_arguments(ctx, target)
        arguments.add("-produce", "library")
        arguments.add("-module-name", module_name)
        arguments.add("-output", _without_extension(klib.path, ".klib"))
        arguments.add_all(dependencies, before_each = "-library")
        arguments.add("-Xmulti-platform")
        if ctx.attr.explicit_api:
            arguments.add("-Xexplicit-api=strict")
        arguments.add_all(ctx.files.srcs)

        _run_compiler(
            ctx,
            target = target,
            arguments = arguments,
            inputs = depset(ctx.files.srcs, transitive = [dependencies]),
            outputs = [klib],
            mnemonic = "KotlinNativeCompile",
            progress_message = "Compiling %{label} with Kotlin/Native for " + target,
        )
        klibs[target] = [klib]
        transitive_klibs[target] = depset([klib], transitive = [dependencies])

    return [
        DefaultInfo(files = depset([klib for target in KOTLIN_NATIVE_TARGETS for klib in klibs[target]])),
        KotlinNativeInfo(klibs = klibs, transitive_klibs = transitive_klibs),
    ]

kt_native_library = rule(
    implementation = _kt_native_library_impl,
    doc = "Compiles Kotlin sources into a klib for every Kotlin/Native target of targets.bzl.",
    attrs = _COMPILER_ATTRS | {
        "deps": attr.label_list(providers = [KotlinNativeInfo], doc = "Kotlin/Native libraries the sources use."),
        "explicit_api": attr.bool(doc = "Whether every declaration must state its visibility, as `explicitApi()` in Gradle."),
        "module_name": attr.string(doc = "Unique name of the klib. Derived from the package when empty."),
        "srcs": attr.label_list(allow_files = [".kt"], doc = "Kotlin sources: common code and iOS code together."),
    },
)

# --- kt_native_test ---

_TEST_RUNNER = """#!/usr/bin/env bash
# Runs the Kotlin/Native tests of {label} in an iOS simulator, as the Kotlin Gradle plugin does.
#
#   KOTLIN_NATIVE_TEST_DEVICE   name or UDID of the simulator. Default: "{device}".
set -euo pipefail

device="${{KOTLIN_NATIVE_TEST_DEVICE:-{device}}}"
executable="$PWD/{executable}"

if [[ -n "${{TESTBRIDGE_TEST_ONLY:-}}" ]]; then
  # bazel test --test_filter=<pattern>
  exec /usr/bin/xcrun simctl spawn --standalone "$device" "$executable" "--ktest_filter=$TESTBRIDGE_TEST_ONLY"
fi
exec /usr/bin/xcrun simctl spawn --standalone "$device" "$executable"
"""

def _kt_native_test_impl(ctx):
    target = KOTLIN_NATIVE_TEST_TARGET
    associates = [dep[KotlinNativeInfo] for dep in ctx.attr.associates]
    deps = [dep[KotlinNativeInfo] for dep in ctx.attr.deps]
    dependencies = _dependency_klibs(associates + deps, target)
    executable = ctx.actions.declare_file(ctx.label.name + ".kexe")

    arguments = _compiler_arguments(ctx, target)
    arguments.add("-produce", "program")
    arguments.add("-generate-test-runner")
    arguments.add("-g")
    arguments.add("-output", _without_extension(executable.path, ".kexe"))
    arguments.add_all(dependencies, before_each = "-library")

    # The tests see the `internal` declarations of the module they test.
    friends = [klib for info in associates for klib in info.klibs[target]]
    if friends:
        arguments.add_joined("-friend-modules", friends, join_with = ":")
    arguments.add("-Xmulti-platform")
    arguments.add_all(ctx.files.srcs)

    _run_compiler(
        ctx,
        target = target,
        arguments = arguments,
        inputs = depset(ctx.files.srcs, transitive = [dependencies]),
        outputs = [executable],
        mnemonic = "KotlinNativeTestLink",
        progress_message = "Linking the Kotlin/Native tests %{label} for " + target,
    )

    runner = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = runner,
        content = _TEST_RUNNER.format(
            device = ctx.attr.device,
            executable = executable.short_path,
            label = ctx.label,
        ),
        is_executable = True,
    )

    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    return [
        DefaultInfo(
            executable = runner,
            files = depset([runner, executable]),
            runfiles = ctx.runfiles(files = [executable]),
        ),
        RunEnvironmentInfo(
            environment = apple_common.apple_host_system_env(xcode_config),
            inherited_environment = ["KOTLIN_NATIVE_TEST_DEVICE"],
        ),
        testing.ExecutionInfo(_xcode_execution_requirements(xcode_config)),
    ]

kt_native_test = rule(
    implementation = _kt_native_test_impl,
    doc = "Compiles Kotlin tests for the iOS simulator and runs them there, with the Kotlin/Native test runner.",
    test = True,
    attrs = _COMPILER_ATTRS | {
        "associates": attr.label_list(
            providers = [KotlinNativeInfo],
            doc = "The libraries under test, whose `internal` declarations the tests see.",
        ),
        "deps": attr.label_list(providers = [KotlinNativeInfo], doc = "Other Kotlin/Native libraries the tests use."),
        "device": attr.string(default = "iPhone 17", doc = "Simulator used when KOTLIN_NATIVE_TEST_DEVICE is not set."),
        "srcs": attr.label_list(allow_files = [".kt"], doc = "Kotlin test sources."),
    },
)

# --- kt_native_framework ---

def _kt_native_framework_impl(ctx):
    target = ctx.attr.target
    name = ctx.attr.framework_name
    main = ctx.attr.main[KotlinNativeInfo]
    main_klibs = main.klibs[target]
    libraries = [klib for klib in main.transitive_klibs[target].to_list() if klib not in main_klibs]

    exported = []
    for export in ctx.attr.exports:
        for klib in export[KotlinNativeInfo].klibs[target]:
            if klib not in libraries:
                fail("{} exports {}, which is not a dependency of {}.".format(ctx.label, export.label, ctx.attr.main.label))
            exported.append(klib)

    # What the compiler writes for a static framework. Declared one by one: the Apple rules read
    # the headers, the module map and the binary as separate files.
    directory = "{}/{}.framework".format(ctx.label.name, name)
    files = [
        ctx.actions.declare_file(directory + "/" + path)
        for path in [
            name,
            "Headers/{}.h".format(name),
            "Info.plist",
            "Modules/module.modulemap",
        ]
    ]
    framework_directory = files[0].dirname

    arguments = _compiler_arguments(ctx, target)
    arguments.add("-produce", "framework")
    arguments.add("-Xstatic-framework")
    arguments.add("-output", _without_extension(framework_directory, ".framework"))
    arguments.add_all(main_klibs, format_each = "-Xinclude=%s")
    arguments.add_all(libraries, before_each = "-library")
    arguments.add_all(exported, format_each = "-Xexport-library=%s")
    if ctx.attr.bundle_id:
        arguments.add("-Xbinary=bundleId=" + ctx.attr.bundle_id)
    arguments.add("-opt" if ctx.var["COMPILATION_MODE"] == "opt" else "-g")

    _run_compiler(
        ctx,
        target = target,
        arguments = arguments,
        inputs = main.transitive_klibs[target],
        outputs = files,
        mnemonic = "KotlinNativeLink",
        progress_message = "Linking the framework {} of %{{label}} for {}".format(name, target),
    )
    return [
        DefaultInfo(files = depset(files)),
        KotlinNativeFrameworkInfo(
            name = name,
            target = target,
            directory = framework_directory,
            files = files,
        ),
    ]

kt_native_framework = rule(
    implementation = _kt_native_framework_impl,
    doc = """Links a static Apple framework for one Kotlin/Native target.

Swift sees the declarations of `main` and of `exports` under their Kotlin names, through the
Objective-C header that the compiler writes. Every other module keeps a prefix in Swift.
""",
    attrs = _COMPILER_ATTRS | {
        "bundle_id": attr.string(doc = "CFBundleIdentifier of the framework."),
        "exports": attr.label_list(
            providers = [KotlinNativeInfo],
            doc = "Dependencies of `main` whose API is part of the framework API.",
        ),
        "framework_name": attr.string(mandatory = True, doc = "Name of the framework, and of the module Swift imports."),
        "main": attr.label(mandatory = True, providers = [KotlinNativeInfo], doc = "The library that the framework is made of."),
        "target": attr.string(mandatory = True, values = KOTLIN_NATIVE_TARGETS, doc = "The Kotlin/Native target."),
    },
)

# --- kt_native_xcframework ---

_CREATE_XCFRAMEWORK = """set -euo pipefail
output="$1"
name="$2"
shift 2
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
/usr/bin/xcrun xcodebuild -create-xcframework "$@" -output "$scratch/$name.xcframework" > /dev/null
rm -rf "$output"
mkdir -p "$output"
cp -R "$scratch/$name.xcframework/." "$output/"
"""

def _kt_native_xcframework_impl(ctx):
    frameworks = [framework[KotlinNativeFrameworkInfo] for framework in ctx.attr.frameworks]
    names = {framework.name: True for framework in frameworks}
    if len(names) != 1:
        fail("{}: every framework must have the same name, got {}.".format(ctx.label, sorted(names)))
    name = frameworks[0].name
    output = ctx.actions.declare_directory(name + ".xcframework")

    arguments = ctx.actions.args()
    arguments.add(output.path)
    arguments.add(name)
    for framework in frameworks:
        arguments.add("-framework", framework.directory)

    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    ctx.actions.run_shell(
        command = _CREATE_XCFRAMEWORK,
        arguments = [arguments],
        inputs = [file for framework in frameworks for file in framework.files],
        outputs = [output],
        env = apple_common.apple_host_system_env(xcode_config),
        use_default_shell_env = True,
        execution_requirements = _xcode_execution_requirements(xcode_config),
        mnemonic = "KotlinNativeXCFramework",
        progress_message = "Assembling %{output}",
    )
    return [DefaultInfo(files = depset([output]))]

kt_native_xcframework = rule(
    implementation = _kt_native_xcframework_impl,
    doc = "Assembles frameworks of the same name, one per Kotlin/Native target, into an XCFramework.",
    attrs = {
        "frameworks": attr.label_list(mandatory = True, providers = [KotlinNativeFrameworkInfo]),
        "_xcode_config": _COMPILER_ATTRS["_xcode_config"],
    },
)

# --- kt_native_import ---

def _kt_native_import_impl(ctx):
    klibs = {target: [] for target in KOTLIN_NATIVE_TARGETS}
    for files, target in ctx.attr.klibs.items():
        klibs.setdefault(target, []).extend(files.files.to_list())
    deps = [dep[KotlinNativeInfo] for dep in ctx.attr.deps]
    transitive_klibs = {
        target: depset(klibs[target], transitive = [dep.transitive_klibs[target] for dep in deps if target in dep.transitive_klibs])
        for target in klibs
    }
    return [
        DefaultInfo(files = depset([klib for target in klibs for klib in klibs[target]])),
        KotlinNativeInfo(klibs = klibs, transitive_klibs = transitive_klibs),
    ]

kt_native_import = rule(
    implementation = _kt_native_import_impl,
    doc = "Klibs of a library, downloaded by the module extension: see repositories.bzl.",
    attrs = {
        "coordinates": attr.string(doc = "Maven coordinates of the library, for people."),
        "deps": attr.label_list(providers = [KotlinNativeInfo]),
        "klibs": attr.label_keyed_string_dict(allow_files = [".klib"], doc = "Each klib -> its Kotlin/Native target."),
    },
)
