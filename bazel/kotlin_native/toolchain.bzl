"""`kotlin_native_toolchain`: the compiler of the `@kotlin_native` repository, as a provider.

Only the BUILD file that `kotlin_native_distribution` writes uses this rule.
"""

load(":providers.bzl", "KotlinNativeToolchainInfo")

def _kotlin_native_toolchain_impl(ctx):
    if not ctx.file.konanc:
        return [KotlinNativeToolchainInfo(
            supported = False,
            host = ctx.attr.host,
            konanc = None,
            data = None,
            files = None,
            target_files = None,
        )]

    return [KotlinNativeToolchainInfo(
        supported = True,
        host = ctx.attr.host,
        konanc = ctx.file.konanc,
        data = ctx.label.workspace_root + "/" + ctx.attr.data,
        files = depset(ctx.files.files),
        target_files = {
            target: files[DefaultInfo].files
            for files, target in ctx.attr.target_files.items()
        },
    )]

kotlin_native_toolchain = rule(
    implementation = _kotlin_native_toolchain_impl,
    doc = "The Kotlin/Native compiler, or its absence when the host cannot run it.",
    attrs = {
        "data": attr.string(doc = "Data directory of the compiler, relative to the repository."),
        "files": attr.label_list(allow_files = True, doc = "Files that every compiler action reads."),
        "host": attr.string(mandatory = True, doc = "Operating system and architecture of the host."),
        "konanc": attr.label(allow_single_file = True, doc = "bin/konanc of the distribution. Absent on an unsupported host."),
        "target_files": attr.label_keyed_string_dict(
            allow_files = True,
            doc = "Files read for one Kotlin/Native target only, such as its platform libraries -> the target.",
        ),
    },
)
