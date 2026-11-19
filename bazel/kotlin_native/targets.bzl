"""Kotlin/Native targets of the build. The rules, the compiler and the klib repositories all read them."""

# Devices, and simulators on Apple silicon: what the iOS application runs on.
KOTLIN_NATIVE_TARGETS = [
    "ios_arm64",
    "ios_simulator_arm64",
]

# The tests run in an iOS simulator of the Mac that builds them.
KOTLIN_NATIVE_TEST_TARGET = "ios_simulator_arm64"
