"""Macros of the shared Kotlin Multiplatform modules: `kmp_core`, `kmp_feature` and `kmp_umbrella`.

A shared module keeps the layout of a Gradle Kotlin Multiplatform module:

    BUILD.bazel                      one macro call
    src/commonMain/kotlin/**/*.kt    code for Android and iOS
    src/commonTest/kotlin/**/*.kt    tests, run on the JVM and in an iOS simulator
    src/iosMain/kotlin/**/*.kt       optional: code for iOS only
    src/iosTest/kotlin/**/*.kt       optional: tests for iOS only

Each macro declares, for a module <name>:

    <name>              commonMain on the JVM, for Android: a Kotlin library
    <name>_native       commonMain and iosMain for iOS: one klib per Kotlin/Native target
    <name>_test         the JVM tests of commonTest
    <name>_native_test  commonTest and iosTest in an iOS simulator, on an Apple silicon Mac only

Kotlin/Native targets are incompatible with other hosts: `bazel test //...` skips them on Linux.

Visibility enforces the module rules of AGENTS.md: a feature is visible to the umbrella, to the
Android feature of the same name and to the Android application only, so no feature can depend
on another one.
"""

load("@rules_apple//apple:apple.bzl", "apple_static_framework_import")
load("@rules_kotlin//kotlin:jvm.bzl", "kt_jvm_library", "kt_jvm_test")
load(
    "//bazel/kotlin_native:defs.bzl",
    "KOTLIN_NATIVE_COMPATIBLE_WITH",
    "kt_native_framework",
    "kt_native_library",
    "kt_native_test",
    "kt_native_xcframework",
)
load("//bazel/kotlin_native:targets.bzl", "KOTLIN_NATIVE_TARGETS")
load("//bazel/kotlin:junit.bzl", "junit_suite")

# Package of the Kotlin code, and base of the bundle identifiers.
BASE_PACKAGE = "com.example.modular"

# Name of the framework that Swift imports. ios/SharedKit and tools/shared/sync rely on it.
SHARED_FRAMEWORK_NAME = "Shared"

# The libraries every shared module uses, on the JVM and for iOS. Versions are in MODULE.bazel.
_COROUTINES = struct(
    jvm = "@maven//:org_jetbrains_kotlinx_kotlinx_coroutines_core",
    native = "@klibs//:org_jetbrains_kotlinx_kotlinx_coroutines_core",
)
_COROUTINES_TEST = struct(
    jvm = "@maven//:org_jetbrains_kotlinx_kotlinx_coroutines_test",
    native = "@klibs//:org_jetbrains_kotlinx_kotlinx_coroutines_test",
)
_VIEWMODEL = struct(
    jvm = "@maven//:androidx_lifecycle_lifecycle_viewmodel",
    native = "@klibs//:androidx_lifecycle_lifecycle_viewmodel",
)

# kotlin.test runs on JUnit 4 on the JVM. Kotlin/Native has it in its standard library.
_JVM_TEST_DEPS = [
    "@maven//:junit_junit",
    "@rules_kotlin//kotlin/compiler:kotlin-test",
    "@rules_kotlin//kotlin/compiler:kotlin-test-junit",
    _COROUTINES_TEST.jvm,
]

_EXPLICIT_API = "//bazel/kotlin:explicit_api"

def kmp_core(name, deps = []):
    """A shared building block, for `shared/core/<name>`: session, network, model.

    Args:
        name: name of the module, the name of its directory.
        deps: other core modules, as `//shared/core/<name>` labels.
    """
    _check_location(name, "shared/core/")
    _check_modules(deps, ["shared/core/"])
    _kmp_module(
        name = name,
        deps = deps,
        jvm_visibility = [
            "//android:__subpackages__",
            "//shared:__subpackages__",
        ],
        native_visibility = ["//shared:__subpackages__"],
    )

def kmp_feature(name, deps = []):
    """The shared logic of one feature, for `shared/feature/<name>`: ViewModels, states, events.

    The AndroidX ViewModel is part of its API.

    Args:
        name: name of the feature, the name of its directory and of its Android and iOS modules.
        deps: core modules, as `//shared/core/<name>` labels. Never another feature.
    """
    _check_location(name, "shared/feature/")
    _check_modules(deps, ["shared/core/"])
    _kmp_module(
        name = name,
        deps = deps,
        exports = [_VIEWMODEL],
        jvm_visibility = [
            "//android/app:__pkg__",
            "//android/feature/%s:__pkg__" % name,
            "//shared/umbrella:__pkg__",
        ],
        native_visibility = ["//shared/umbrella:__pkg__"],
    )

def kmp_umbrella(name, export_to_swift, deps = []):
    """The only module that produces the iOS framework, for `shared/umbrella`.

    Besides the targets of every module, it declares:

        Shared                  the framework for the iOS build: the one of the device or of the
                                simulator, whichever the build is for
        Shared_<target>         the framework of one Kotlin/Native target
        Shared_xcframework      Shared.xcframework, for the Swift packages: see tools/shared/sync

    Args:
        name: "umbrella".
        export_to_swift: the features whose API Swift sees under their Kotlin names, as
            `//shared/feature/<name>` labels. The AndroidX ViewModel is always exported.
        deps: core modules that the umbrella wires, as `//shared/core/<name>` labels. Swift
            reaches them through ViewModels only.
    """
    if native.package_name() != "shared/umbrella":
        fail("kmp_umbrella is for shared/umbrella only, not for %s." % native.package_name())
    _check_modules(deps, ["shared/core/"])
    _check_modules(export_to_swift, ["shared/feature/"])

    _kmp_module(
        name = name,
        deps = deps + export_to_swift,
        exports = [_VIEWMODEL],
        jvm_exports = export_to_swift,
        jvm_visibility = ["//android/app:__pkg__"],
        native_visibility = ["//visibility:private"],
    )

    frameworks = {}
    for target in KOTLIN_NATIVE_TARGETS:
        framework = "%s_%s" % (SHARED_FRAMEWORK_NAME, target)
        kt_native_framework(
            name = framework,
            bundle_id = BASE_PACKAGE + ".shared",
            exports = [_native_label(module) for module in export_to_swift] + [_VIEWMODEL.native],
            framework_name = SHARED_FRAMEWORK_NAME,
            main = ":%s_native" % name,
            target = target,
            target_compatible_with = KOTLIN_NATIVE_COMPATIBLE_WITH,
        )
        frameworks[target] = ":" + framework

    kt_native_xcframework(
        name = SHARED_FRAMEWORK_NAME + "_xcframework",
        frameworks = [frameworks[target] for target in KOTLIN_NATIVE_TARGETS],
        target_compatible_with = KOTLIN_NATIVE_COMPATIBLE_WITH,
    )

    # Simulators on Apple silicon are the default: Kotlin/Native builds no x86_64 simulator.
    apple_static_framework_import(
        name = SHARED_FRAMEWORK_NAME,
        framework_imports = select({
            "//bazel/kotlin_native:ios_device": [frameworks["ios_arm64"]],
            "//conditions:default": [frameworks["ios_simulator_arm64"]],
        }),
        # The Kotlin/Native runtime is written in C++.
        sdk_dylibs = ["libc++"],
        target_compatible_with = ["@platforms//os:ios"],
        visibility = ["//ios/SharedKit:__pkg__"],
    )

def _kmp_module(name, deps, jvm_visibility, native_visibility, exports = [], jvm_exports = []):
    common = _sources("commonMain")
    kt_jvm_library(
        name = name,
        srcs = common,
        kotlinc_opts = _EXPLICIT_API,
        visibility = jvm_visibility,
        exports = jvm_exports + [library.jvm for library in exports],
        deps = deps + [_COROUTINES.jvm] + [library.jvm for library in exports],
    )
    kt_native_library(
        name = name + "_native",
        srcs = common + _sources("iosMain"),
        explicit_api = True,
        target_compatible_with = KOTLIN_NATIVE_COMPATIBLE_WITH,
        visibility = native_visibility,
        deps = [_native_label(dep) for dep in deps] + [_COROUTINES.native] + [library.native for library in exports],
    )

    tests = _sources("commonTest")
    if tests:
        suite = junit_suite(
            name = name + "_test_suite",
            srcs = tests,
            source_root = "src/commonTest/kotlin",
            package = BASE_PACKAGE + "." + native.package_name().replace("/", "."),
        )
        kt_jvm_test(
            name = name + "_test",
            srcs = tests + [":%s_test_suite" % name],
            associates = [":" + name],
            test_class = suite,
            deps = _JVM_TEST_DEPS + deps,
        )

    native_tests = tests + _sources("iosTest")
    if native_tests:
        kt_native_test(
            name = name + "_native_test",
            srcs = native_tests,
            associates = [":%s_native" % name],
            target_compatible_with = KOTLIN_NATIVE_COMPATIBLE_WITH,
            deps = [_COROUTINES_TEST.native],
        )

def _sources(source_set):
    return native.glob(["src/%s/kotlin/**/*.kt" % source_set], allow_empty = True)

def _native_label(module):
    """The Kotlin/Native library of a module: //shared/core/session -> //shared/core/session:session_native."""
    label = native.package_relative_label(module)
    return label.same_package_label(label.name + "_native")

def _check_location(name, directory):
    if native.package_name() != directory + name:
        fail("The module '%s' must live in %s%s, not in %s." % (name, directory, name, native.package_name()))

def _check_modules(modules, directories):
    for module in modules:
        label = native.package_relative_label(module)
        if label.package.split("/")[-1] != label.name or not [d for d in directories if label.package.startswith(d)]:
            fail("'%s' is not a module of %s: expected a label like //%sname." % (module, " or ".join(directories), directories[0]))
