"""`robolectric_deps_properties`: tells Robolectric where its Android framework jar is.

Robolectric runs the screen tests on an instrumented Android framework, the android-all jar of
one SDK level. The tests run offline: android_local_test points Robolectric to a properties file
that maps the jar coordinates to a path, relative to that file. This rule writes the file for one
jar, so that the build downloads that jar only, and not the jar of every SDK level.
"""

_PREFIX = "android-all-instrumented-"

def _runfiles_path(ctx, file):
    """Path of a file from the root of the runfiles tree."""
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return ctx.workspace_name + "/" + file.short_path

def _robolectric_deps_properties_impl(ctx):
    jar = ctx.file.jar
    if not jar.basename.startswith(_PREFIX) or not jar.basename.endswith(".jar"):
        fail("%s is not an android-all-instrumented jar of Robolectric." % jar.basename)
    version = jar.basename[len(_PREFIX):-len(".jar")]

    properties = ctx.actions.declare_file(ctx.label.name + "/robolectric-deps.properties")
    depth = len(_runfiles_path(ctx, properties).split("/")) - 1
    ctx.actions.write(
        output = properties,
        content = "org.robolectric\\:android-all-instrumented\\:{version}={path}\n".format(
            version = version,
            path = "../" * depth + _runfiles_path(ctx, jar),
        ),
    )
    return [DefaultInfo(
        files = depset([properties]),
        runfiles = ctx.runfiles(files = [properties, jar]),
    )]

robolectric_deps_properties = rule(
    implementation = _robolectric_deps_properties_impl,
    doc = "Writes robolectric-deps.properties for one android-all jar. Its runfiles hold both files.",
    attrs = {
        "jar": attr.label(
            mandatory = True,
            allow_single_file = [".jar"],
            doc = "The android-all-instrumented jar, as downloaded from Maven Central.",
        ),
    },
)
