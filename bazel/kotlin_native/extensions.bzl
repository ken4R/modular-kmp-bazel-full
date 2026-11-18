"""Module extension `kotlin_native`: what MODULE.bazel declares for Kotlin/Native.

    kotlin_native.toolchain(...)   the compiler, in the repository @kotlin_native
    kotlin_native.libraries(...)   the klibs of the Kotlin Multiplatform libraries, in @klibs

Only the root module may use it.
"""

load(":repositories.bzl", "kotlin_native_distribution", "kotlin_native_klibs")

_toolchain = tag_class(
    doc = "The Kotlin/Native compiler. Keep its version on the Kotlin version of rules_kotlin.",
    attrs = {
        "dependencies": attr.string_dict(
            doc = "What the compiler would download on its first run, from konan/konan.properties of the distribution: URL of each archive -> its sha256.",
        ),
        "sha256": attr.string(mandatory = True, doc = "sha256 of the distribution for macOS on Apple silicon."),
        "version": attr.string(mandatory = True, doc = "Kotlin version."),
    },
)

_libraries = tag_class(
    doc = "Kotlin Multiplatform libraries, resolved with their dependencies for every Kotlin/Native target.",
    attrs = {
        "artifacts": attr.string_list(doc = "Libraries, as group:artifact:version."),
        "repositories": attr.string_list(doc = "Maven repositories, searched in order."),
    },
)

def _kotlin_native_impl(module_ctx):
    toolchains = []
    artifacts = []
    repositories = []
    for module in module_ctx.modules:
        if not module.is_root:
            fail("kotlin_native is for the root module only, not for " + module.name)
        toolchains.extend(module.tags.toolchain)
        for libraries in module.tags.libraries:
            artifacts.extend(libraries.artifacts)
            repositories.extend([repository for repository in libraries.repositories if repository not in repositories])

    if len(toolchains) != 1:
        fail("MODULE.bazel must declare exactly one kotlin_native.toolchain.")
    toolchain = toolchains[0]

    kotlin_native_distribution(
        name = "kotlin_native",
        dependencies = toolchain.dependencies,
        sha256 = toolchain.sha256,
        version = toolchain.version,
    )
    kotlin_native_klibs(
        name = "klibs",
        artifacts = artifacts,
        repositories = repositories,
    )
    return module_ctx.extension_metadata(
        root_module_direct_deps = ["kotlin_native", "klibs"],
        root_module_direct_dev_deps = [],
    )

kotlin_native = module_extension(
    implementation = _kotlin_native_impl,
    tag_classes = {
        "libraries": _libraries,
        "toolchain": _toolchain,
    },
)
