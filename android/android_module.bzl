"""Macros of the Android modules: `android_core`, `android_feature` and `android_app`.

An Android module keeps the layout of a Gradle Android module:

    BUILD.bazel                     one macro call
    src/main/kotlin/**/*.kt         Compose code
    src/main/res/**                 optional: Android resources
    src/main/AndroidManifest.xml    the application only: libraries get a generated manifest
    src/test/kotlin/**/*.kt         optional: screen tests, run on the JVM with Robolectric

Each macro declares, for a module <name>:

    <name>          the Kotlin library with its resources, or the APK for `android_app`
    <name>_test     the screen tests, when the module has some

The package of the Kotlin code and of `R` comes from the directory: android/feature/login is
com.example.modular.feature.login. Visibility enforces the module rules of AGENTS.md.
"""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_android//rules:rules.bzl", "android_binary")
load("@rules_kotlin//kotlin:android.bzl", "kt_android_library", "kt_android_local_test")
load("//bazel/kotlin:junit.bzl", "junit_suite")

# Package of the Kotlin code. The application id of the prototype is the same placeholder.
BASE_PACKAGE = "com.example.modular"

# SDK levels. minSdk is a prototype default: the real value is an open decision. targetSdk changes
# runtime behavior, so it moves on its own, and Robolectric must support it: see bazel/android.
# compileSdk is the newest platform installed in ANDROID_HOME, 37 for Compose 1.12.
MIN_SDK = 26
TARGET_SDK = 36

_COMPOSE_COMPILER = "//bazel/kotlin:compose_compiler"

# What every Android module with Compose code uses. Versions are in MODULE.bazel.
_COMPOSE = [
    "@maven//:androidx_compose_material3_material3",
    "@maven//:androidx_compose_ui_ui",
    "@maven//:androidx_compose_ui_ui_tooling_preview",
]

# What a screen needs to observe a shared ViewModel.
_FEATURE = [
    "@maven//:androidx_lifecycle_lifecycle_runtime_compose",
    "@maven//:androidx_lifecycle_lifecycle_viewmodel_compose",
    "@maven//:org_jetbrains_kotlinx_kotlinx_coroutines_core",
]

_APP = _FEATURE + [
    "@maven//:androidx_activity_activity_compose",
    # Dispatchers.Main on Android, for viewModelScope and the Compose code.
    "@maven//:org_jetbrains_kotlinx_kotlinx_coroutines_android",
]

# Screen tests: Compose tests on Robolectric. ui-test-manifest declares the activity that hosts
# the screen under test.
_SCREEN_TEST = [
    "//bazel/android:robolectric_android_all",
    "@maven//:androidx_compose_ui_ui_test_junit4",
    "@maven//:androidx_compose_ui_ui_test_manifest",
    "@maven//:androidx_test_ext_junit",
    "@maven//:junit_junit",
    "@maven//:org_robolectric_robolectric",
]

def android_core(name, deps = []):
    """A Compose library shared by the features, for `android/core/<name>`: design system, components.

    Args:
        name: name of the module, the name of its directory.
        deps: other Android core modules and shared core modules.
    """
    _check_location(name, "android/core/")
    _check_modules(deps, ["android/core/", "shared/core/"])
    _android_library(
        name = name,
        deps = deps + _COMPOSE,
        visibility = ["//android:__subpackages__"],
    )

def android_feature(name, deps = []):
    """The Compose screens of one feature, for `android/feature/<name>`.

    Args:
        name: name of the feature, the name of its shared and iOS modules too.
        deps: the shared feature of the same name, shared core modules and Android core modules.
            Never another feature.
    """
    _check_location(name, "android/feature/")
    _check_modules(deps, ["android/core/", "shared/core/", "shared/feature/" + name])
    _android_library(
        name = name,
        deps = deps + _COMPOSE + _FEATURE,
        visibility = ["//android/app:__pkg__"],
    )

def android_app(name, application_id, deps = []):
    """The Android application, for `android/app`, the only module that may depend on any other.

    Targets: <name>, the APK, and <name>_library, its code and resources.

    Args:
        name: "app".
        application_id: the application id of the APK.
        deps: the modules the application assembles.
    """
    if native.package_name() != "android/app":
        fail("android_app is for android/app only, not for %s." % native.package_name())
    _check_modules(deps, ["android/", "shared/"])

    _android_library(
        name = name + "_library",
        deps = deps + _COMPOSE + _APP,
        visibility = ["//visibility:private"],
        tests = False,
    )
    android_binary(
        name = name,
        custom_package = _namespace(),
        manifest = "src/main/AndroidManifest.xml",
        manifest_values = {
            "applicationId": application_id,
            "minSdkVersion": str(MIN_SDK),
            "targetSdkVersion": str(TARGET_SDK),
            "versionCode": "1",
            "versionName": "0.1.0",
        },
        deps = [":%s_library" % name],
    )

def _android_library(name, deps, visibility, tests = True):
    package = _namespace()
    _manifest(name = name + "_manifest", package = package)
    kt_android_library(
        name = name,
        srcs = native.glob(["src/main/kotlin/**/*.kt"]),
        custom_package = package,
        manifest = ":%s_manifest" % name,
        plugins = [_COMPOSE_COMPILER],
        resource_files = native.glob(["src/main/res/**"], allow_empty = True),
        visibility = visibility,
        deps = deps,
    )

    test_sources = native.glob(["src/test/kotlin/**/*.kt"], allow_empty = True)
    if not tests or not test_sources:
        return
    suite = junit_suite(
        name = name + "_test_suite",
        srcs = test_sources,
        source_root = "src/test/kotlin",
        package = package,
    )
    _manifest(name = name + "_test_manifest", package = package, target_sdk = TARGET_SDK)
    kt_android_local_test(
        name = name + "_test",
        srcs = test_sources + [":%s_test_suite" % name],
        associates = [":" + name],
        custom_package = package,
        manifest = ":%s_test_manifest" % name,
        plugins = [_COMPOSE_COMPILER],
        # Only the android-all jar of TARGET_SDK, instead of the jar of every SDK level.
        robolectric_properties_file = "//bazel/android:robolectric_deps_properties",
        test_class = suite,
        deps = deps + _SCREEN_TEST,
    )

def _manifest(name, package, target_sdk = None):
    """Writes the AndroidManifest.xml of a library or of its tests: Gradle generates them too."""
    uses_sdk = '    <uses-sdk android:minSdkVersion="%d"' % MIN_SDK
    if target_sdk:
        uses_sdk += ' android:targetSdkVersion="%d"' % target_sdk
    write_file(
        name = name,
        out = name + "/AndroidManifest.xml",
        content = [
            '<?xml version="1.0" encoding="utf-8"?>',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="%s">' % package,
            uses_sdk + " />",
            "    <application />",
            "</manifest>",
            "",
        ],
        visibility = ["//visibility:private"],
    )

def _namespace():
    """com.example.modular followed by the directories of the module, without android/."""
    return ".".join([BASE_PACKAGE] + native.package_name().split("/")[1:])

def _check_location(name, directory):
    if native.package_name() != directory + name:
        fail("The module '%s' must live in %s%s, not in %s." % (name, directory, name, native.package_name()))

def _check_modules(modules, prefixes):
    """Fails on a dependency that the module rules forbid. Libraries of other repositories are allowed."""
    for module in modules:
        label = native.package_relative_label(module)
        if label.repo_name:
            continue
        if not [prefix for prefix in prefixes if (label.package + "/").startswith(prefix.rstrip("/") + "/")]:
            fail("'%s' is not allowed here: this module may depend on %s only." % (module, ", ".join(prefixes)))
