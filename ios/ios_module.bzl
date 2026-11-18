"""`ios_module`: one iOS module, built by Bazel and usable as a Swift package.

A module is a directory with this layout:

    BUILD.bazel                     one `ios_module(...)` call
    Package.swift                   generated from BUILD.bazel, committed
    Sources/<Name>/**/*.swift
    Tests/<Name>Tests/**/*.swift    optional

BUILD.bazel is the source of truth. Package.swift is written from the same declaration, so the
module also opens in Xcode as a Swift package, and a test fails when the two disagree:

    bazel run //ios/Features/Login:package_swift          rewrites Package.swift
    bazel test //ios/Features/Login:package_swift_test    fails when Package.swift is stale
"""

load("@bazel_lib//lib:write_source_files.bzl", "write_source_files")
load("@rules_apple//apple:ios.bzl", "ios_unit_test")
load("@rules_swift//swift:swift_library.bzl", "swift_library")
load(":package_manifest.bzl", "package_manifest")

# Oldest iOS version the application and every module support.
IOS_MINIMUM_OS_VERSION = "17.0"

# Constraint of every target that compiles for iOS. Bazel runs on a Mac, so `bazel test //ios/...`
# skips these targets as top-level targets instead of building them for macOS. They are built
# through the application and the test bundles, which switch to iOS.
IOS_ONLY = ["@platforms//os:ios"]

# Visibility of the targets that the Xcode project of //ios lists. rules_xcodeproj reads them from a
# package it generates in another repository, which its `generated` package group covers.
XCODE_PROJECT_VISIBILITY = [
    "//ios:__pkg__",
    "@rules_xcodeproj//xcodeproj:generated",
]

_FEATURES_DIRECTORY = "ios/Features/"

def ios_module(name, deps = [], frameworks = [], visibility = None):
    """Declares an iOS module: a Swift library, its tests and its Package.swift.

    Targets:
        <name>                  the Swift library, with the module name <name>
        <name>Tests             the unit tests, when `Tests/<name>Tests` has sources
        package_swift           `bazel run` it to rewrite Package.swift
        package_swift_test      fails when Package.swift is stale

    Visibility follows the module rules: a feature is visible to the application only, so a feature
    can never depend on another feature. Any other module is visible to the whole `//ios` tree.

    Args:
        name: name of the module. It must be the name of its directory.
        deps: the other iOS modules it uses, as `//ios/<path>/<Name>` labels.
        frameworks: frameworks that Bazel builds from the Kotlin code, such as
            `//shared/umbrella:Shared`. Swift imports each one under the name of its label. In
            Package.swift, a framework is the binary target `Frameworks/<name>.xcframework`, which
            tools/shared/sync copies there.
        visibility: overrides the visibility described above.
    """
    package = native.package_name()
    if package.split("/")[-1] != name:
        fail("The module '%s' must live in a directory with the same name, not in '%s'." % (name, package))

    if visibility == None:
        if package.startswith(_FEATURES_DIRECTORY):
            visibility = ["//ios/App:__pkg__"]
        else:
            visibility = ["//ios:__subpackages__"]

    module_packages = []
    for dep in deps:
        label = native.package_relative_label(dep)
        if label.package.split("/")[-1] != label.name:
            fail("'%s' is not an iOS module: expected a label like //ios/Core/DesignSystem." % dep)
        module_packages.append(label.package)

    # Swift packages read the frameworks where tools/shared/sync copies them.
    xcframeworks = {}
    for framework in frameworks:
        framework_name = native.package_relative_label(framework).name
        xcframeworks[framework_name] = "Frameworks/%s.xcframework" % framework_name

    swift_library(
        name = name,
        srcs = native.glob(["Sources/%s/**/*.swift" % name]),
        module_name = name,
        target_compatible_with = IOS_ONLY,
        visibility = visibility,
        deps = deps + frameworks,
    )

    tests = name + "Tests"
    test_sources = native.glob(["Tests/%s/**/*.swift" % tests], allow_empty = True)
    if test_sources:
        swift_library(
            name = tests + "Library",
            testonly = True,
            srcs = test_sources,
            module_name = tests,
            target_compatible_with = IOS_ONLY,
            visibility = ["//visibility:private"],
            deps = [":" + name],
        )
        ios_unit_test(
            name = tests,
            minimum_os_version = IOS_MINIMUM_OS_VERSION,
            visibility = XCODE_PROJECT_VISIBILITY,
            deps = [":" + tests + "Library"],
        )

    _swift_package_manifest(
        name = "package_swift_generated",
        out = "Package.generated.swift",
        dependencies = module_packages,
        has_tests = bool(test_sources),
        module = name,
        xcframeworks = xcframeworks,
        visibility = ["//visibility:private"],
    )
    write_source_files(
        name = "package_swift",
        files = {"Package.swift": ":package_swift_generated"},
    )

def _swift_package_manifest_impl(ctx):
    ctx.actions.write(
        output = ctx.outputs.out,
        content = package_manifest(
            module = ctx.attr.module,
            bazel_package = ctx.label.package,
            minimum_ios_version = IOS_MINIMUM_OS_VERSION,
            dependencies = ctx.attr.dependencies,
            xcframeworks = ctx.attr.xcframeworks,
            has_tests = ctx.attr.has_tests,
        ),
    )
    return [DefaultInfo(files = depset([ctx.outputs.out]))]

_swift_package_manifest = rule(
    implementation = _swift_package_manifest_impl,
    doc = "Writes the Package.swift that matches an `ios_module` declaration.",
    attrs = {
        "dependencies": attr.string_list(doc = "Bazel packages of the modules this one depends on."),
        "has_tests": attr.bool(doc = "Whether the module has tests."),
        "module": attr.string(mandatory = True, doc = "Name of the module."),
        "out": attr.output(mandatory = True, doc = "The generated file."),
        "xcframeworks": attr.string_dict(doc = "Framework name -> path of its .xcframework in the module."),
    },
)
