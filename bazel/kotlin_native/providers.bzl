"""Providers of the Kotlin/Native rules."""

KotlinNativeInfo = provider(
    doc = "The klibs of a Kotlin/Native module, for each Kotlin/Native target it is built for.",
    fields = {
        "klibs": "dict: Kotlin/Native target -> list of File, the klibs of this module.",
        "transitive_klibs": "dict: Kotlin/Native target -> depset of File, these klibs and those of every dependency.",
    },
)

KotlinNativeFrameworkInfo = provider(
    doc = "An Apple framework linked by the Kotlin/Native compiler, for one Kotlin/Native target.",
    fields = {
        "name": "string: name of the framework, and of the module Swift imports.",
        "target": "string: the Kotlin/Native target, such as ios_simulator_arm64.",
        "directory": "string: path of the .framework directory, from the execution root.",
        "files": "list of File: every file of the framework.",
    },
)

KotlinNativeToolchainInfo = provider(
    doc = "The Kotlin/Native compiler that MODULE.bazel downloads, with the files its actions read.",
    fields = {
        "supported": "bool: False when the host cannot run the compiler. The fields below are then None.",
        "host": "string: the host, for error messages.",
        "konanc": "File: bin/konanc of the distribution, the compiler.",
        "data": "string: path of the compiler data directory, which holds dependencies/, from the execution root.",
        "files": "depset of File: what every compiler action reads.",
        "target_files": "dict: Kotlin/Native target -> depset of File, what the actions of that target read too.",
    },
)
