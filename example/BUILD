load("@rules_foreign_cc//foreign_cc:defs.bzl", "meson")

cc_binary(
    name = "cc_binary",
    srcs = ["@example_repo"],
)

meson(
    name = "meson",
    lib_source = "@example_repo",
    out_binaries = ["example"],
)
