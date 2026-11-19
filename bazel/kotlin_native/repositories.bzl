"""Repository rules of the Kotlin/Native rules: the compiler, and the klibs of the libraries.

The module extension of extensions.bzl calls them with what MODULE.bazel declares.
"""

load(":targets.bzl", "KOTLIN_NATIVE_TARGETS")

# The distribution for Apple silicon Macs, with the platform libraries of the Apple SDKs.
_DISTRIBUTION_URL = "https://repo1.maven.org/maven2/org/jetbrains/kotlin/kotlin-native-prebuilt/{version}/kotlin-native-prebuilt-{version}-macos-aarch64.tar.gz"

_TOOLCHAIN_BZL = str(Label("//bazel/kotlin_native:toolchain.bzl"))
_DEFS_BZL = str(Label("//bazel/kotlin_native:defs.bzl"))

def _is_supported_host(rctx):
    return rctx.os.name.startswith("mac") and rctx.os.arch in ["aarch64", "arm64"]

def _kotlin_native_distribution_impl(rctx):
    host = "{} {}".format(rctx.os.name, rctx.os.arch)
    if not _is_supported_host(rctx):
        rctx.file("BUILD.bazel", """load("{bzl}", "kotlin_native_toolchain")

# Kotlin/Native builds for iOS on an Apple silicon Mac only. This host is {host}.
kotlin_native_toolchain(
    name = "toolchain",
    host = "{host}",
    visibility = ["//visibility:public"],
)
""".format(bzl = _TOOLCHAIN_BZL, host = host))
        return

    rctx.download_and_extract(
        url = _DISTRIBUTION_URL.format(version = rctx.attr.version),
        sha256 = rctx.attr.sha256,
        strip_prefix = "kotlin-native-prebuilt-macos-aarch64-" + rctx.attr.version,
        output = "dist",
    )

    # The compiler downloads LLVM and libffi into <data>/dependencies on its first run. They are
    # downloaded here instead, and marked as extracted the way the compiler does it, so that the
    # compiler runs offline (airplaneMode) and every machine uses the same files.
    names = []
    for url, sha256 in rctx.attr.dependencies.items():
        archive = url.rsplit("/", 1)[-1]
        if not archive.endswith(".tar.gz"):
            fail("Kotlin/Native dependency {}: expected a .tar.gz archive.".format(url))
        name = archive[:-len(".tar.gz")]
        rctx.download_and_extract(url = url, sha256 = sha256, output = "data/dependencies")
        if not rctx.path("data/dependencies/" + name).exists:
            fail("Kotlin/Native dependency {}: the archive holds no directory {}.".format(url, name))
        names.append(name)
    rctx.file("data/dependencies/.extracted", "".join([name + "\n" for name in names]))

    # The compiler locks this file before it checks its dependencies.
    rctx.file("data/dependencies/cache/.lock", "")

    filegroups = []
    target_files = []
    for target in KOTLIN_NATIVE_TARGETS:
        filegroups.append("""
filegroup(
    name = "{target}_files",
    srcs = glob([
        "dist/klib/platform/{target}/**",
        "dist/klib/cache/{target}-*/**",
    ]),
)
""".format(target = target))
        target_files.append('        ":{target}_files": "{target}",'.format(target = target))

    rctx.file("BUILD.bazel", """load("{bzl}", "kotlin_native_toolchain")

package(default_visibility = ["//visibility:public"])

# Kotlin/Native {version} for Apple silicon Macs. See bazel/kotlin_native in the main repository.
kotlin_native_toolchain(
    name = "toolchain",
    data = "data",
    files = glob(
        [
            "dist/**",
            "data/**",
        ],
        exclude = [
            # Read by the actions of one target only: see target_files.
            "dist/klib/platform/**",
            "dist/klib/cache/**",
            # Written by the compiler.
            "data/dependencies/cache/**",
        ],
    ),
    host = "{host}",
    konanc = "dist/bin/konanc",
    target_files = {{
{target_files}
    }},
)
{filegroups}""".format(
        bzl = _TOOLCHAIN_BZL,
        filegroups = "".join(filegroups),
        host = host,
        target_files = "\n".join(target_files),
        version = rctx.attr.version,
    ))

kotlin_native_distribution = repository_rule(
    implementation = _kotlin_native_distribution_impl,
    doc = "Downloads the Kotlin/Native compiler and its dependencies, on an Apple silicon Mac only.",
    attrs = {
        "dependencies": attr.string_dict(doc = "URL of each dependency archive of the compiler -> its sha256."),
        "sha256": attr.string(mandatory = True, doc = "sha256 of the distribution."),
        "version": attr.string(mandatory = True, doc = "Kotlin version."),
    },
)

# --- klibs of the Kotlin Multiplatform libraries ---

def _target_name(key):
    """Bazel name of a library: "androidx.lifecycle:lifecycle-viewmodel" -> "androidx_lifecycle_lifecycle_viewmodel"."""
    return key.replace(".", "_").replace("-", "_").replace(":", "_")

def _version_key(version):
    """Sort key of a version: numbers compare as numbers, and 1.0-alpha01 < 1.0 < 1.0.1."""
    key = []
    for part in version.replace("-", ".").split("."):
        if part.isdigit():
            key.append((1, int(part), ""))
        else:
            key.append((0, 0, part))
    key.append((1, -1, ""))
    return key

def _module_path(group, module, version):
    return "{}/{}/{}/{}-{}.module".format(group.replace(".", "/"), module, version, module, version)

def _metadata(rctx, cache, path, coordinates):
    """Downloads and decodes a Gradle module metadata file, once."""
    if path not in cache:
        output = "metadata/" + path
        result = rctx.download(
            url = [repository + "/" + path for repository in rctx.attr.repositories],
            output = output,
            allow_fail = True,
        )
        if not result.success:
            fail("{} has no Gradle module metadata in {}.".format(coordinates, rctx.attr.repositories))
        cache[path] = json.decode(rctx.read(output))
    return cache[path]

def _is_api_variant(variant, target):
    attributes = variant.get("attributes", {})
    return (
        attributes.get("org.jetbrains.kotlin.platform.type") == "native" and
        attributes.get("org.jetbrains.kotlin.native.target") == target and
        attributes.get("org.gradle.usage") == "kotlin-api" and
        attributes.get("org.gradle.category", "library") == "library"
    )

def _is_provided_by_the_compiler(group, module):
    return group == "org.jetbrains.kotlin" and (module.startswith("kotlin-stdlib") or module.startswith("kotlin-test"))

def _native_variant(rctx, cache, group, module, version, target):
    """The klibs and the dependencies that a library publishes for one Kotlin/Native target."""
    coordinates = "{}:{}:{}".format(group, module, version)
    path = _module_path(group, module, version)
    found = None
    for variant in _metadata(rctx, cache, path, coordinates).get("variants", []):
        if _is_api_variant(variant, target):
            found = variant
            break
    if found == None:
        fail("{} publishes no klib for the Kotlin/Native target {}.".format(coordinates, target))

    # A multiplatform library usually publishes each target as a module of its own.
    available_at = found.get("available-at")
    if available_at:
        path = _module_path(available_at["group"], available_at["module"], available_at["version"])
        found = None
        for variant in _metadata(rctx, cache, path, coordinates).get("variants", []):
            if _is_api_variant(variant, target):
                found = variant
                break
        if found == None:
            fail("{}: the metadata of {} has no variant for {}.".format(coordinates, available_at["module"], target))

    directory = path.rsplit("/", 1)[0]
    files = []
    for file in found.get("files", []):
        if file["url"].endswith(".klib"):
            files.append(struct(path = directory + "/" + file["url"], sha256 = file["sha256"]))

    dependencies = []
    for dependency in found.get("dependencies", []):
        if dependency.get("attributes", {}).get("org.gradle.category") in ["platform", "enforced-platform"]:
            continue
        if _is_provided_by_the_compiler(dependency["group"], dependency["module"]):
            continue
        requested = dependency.get("version", {})
        dependency_version = requested.get("strictly") or requested.get("requires") or requested.get("prefers")
        if not dependency_version:
            fail("{}: no version for its dependency {}:{}.".format(coordinates, dependency["group"], dependency["module"]))
        dependencies.append((dependency["group"], dependency["module"], dependency_version))

    return struct(files = files, dependencies = dependencies)

def _resolve(rctx, cache, roots, target):
    """Resolves the libraries and their dependencies for one target. The highest version wins, as in Gradle.

    Returns:
        dict: "group:module" -> struct(version, files, dependencies).
    """
    selected = {}
    variants = {}
    queue = list(roots)
    for _ in range(100000):
        if not queue:
            break
        group, module, version = queue.pop(0)
        key = group + ":" + module
        if key in selected and _version_key(version) <= _version_key(selected[key]):
            continue
        selected[key] = version
        if (key, version) not in variants:
            variants[(key, version)] = _native_variant(rctx, cache, group, module, version, target)
        queue.extend(variants[(key, version)].dependencies)
    if queue:
        fail("The dependency graph of the klibs does not converge.")

    # Keep only what the selected versions still reach: a lower version may have had other dependencies.
    reachable = {}
    stack = [group + ":" + module for group, module, _ in roots]
    for _ in range(100000):
        if not stack:
            break
        key = stack.pop()
        if key in reachable:
            continue
        reachable[key] = True
        stack.extend([group + ":" + module for group, module, _ in variants[(key, selected[key])].dependencies])

    resolved = {}
    for key in reachable:
        variant = variants[(key, selected[key])]
        resolved[key] = struct(version = selected[key], files = variant.files, dependencies = variant.dependencies)
    return resolved

def _kotlin_native_klibs_impl(rctx):
    roots = []
    for artifact in rctx.attr.artifacts:
        parts = artifact.split(":")
        if len(parts) != 3:
            fail("kotlin_native.libraries: expected group:artifact:version, got " + artifact)
        roots.append((parts[0], parts[1], parts[2]))

    cache = {}
    libraries = {}
    for target in KOTLIN_NATIVE_TARGETS:
        for key, library in _resolve(rctx, cache, roots, target).items():
            entry = libraries.setdefault(key, struct(versions = {}, klibs = {}, dependencies = {}))
            entry.versions[library.version] = True
            for file in library.files:
                output = "{}/{}/{}".format(target, key.replace(":", "/"), file.path.rsplit("/", 1)[-1])
                rctx.download(
                    url = [repository + "/" + file.path for repository in rctx.attr.repositories],
                    output = output,
                    sha256 = file.sha256,
                )
                entry.klibs[output] = target
            for group, module, _ in library.dependencies:
                entry.dependencies[group + ":" + module] = True

    lines = [
        'load("{}", "kt_native_import")'.format(_DEFS_BZL),
        "",
        "# The klibs of the Kotlin Multiplatform libraries that MODULE.bazel lists, with their",
        "# dependencies, resolved from the Gradle module metadata that the libraries publish.",
        'package(default_visibility = ["//visibility:public"])',
    ]
    for key in sorted(libraries):
        entry = libraries[key]
        lines.append("")
        lines.append("kt_native_import(")
        lines.append('    name = "{}",'.format(_target_name(key)))
        lines.append('    coordinates = "{}:{}",'.format(key, ", ".join(sorted(entry.versions))))
        lines.append("    klibs = {")
        for path in sorted(entry.klibs):
            lines.append('        "{}": "{}",'.format(path, entry.klibs[path]))
        lines.append("    },")
        dependencies = sorted([_target_name(dependency) for dependency in entry.dependencies if dependency in libraries])
        if dependencies:
            lines.append("    deps = [")
            for dependency in dependencies:
                lines.append('        ":{}",'.format(dependency))
            lines.append("    ],")
        lines.append(")")
    rctx.file("BUILD.bazel", "\n".join(lines) + "\n")

kotlin_native_klibs = repository_rule(
    implementation = _kotlin_native_klibs_impl,
    doc = "Downloads the klibs of Kotlin Multiplatform libraries and of their dependencies.",
    attrs = {
        "artifacts": attr.string_list(doc = "Libraries, as group:artifact:version."),
        "repositories": attr.string_list(doc = "Maven repositories, searched in order."),
    },
)
