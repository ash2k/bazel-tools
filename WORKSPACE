workspace(name = "com_github_ash2k_bazel_tools")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "56d8c5a5c91e1af73eca71a6fab2ced959b67c86d12ba37feedb0a2dfea441a6",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.37.0/rules_go-v0.37.0.zip",
    ],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "448e37e0dbf61d6fa8f00aaa12d191745e14f07c31cabfa731f0c8e8a4f41b97",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.28.0/bazel-gazelle-v0.28.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.28.0/bazel-gazelle-v0.28.0.tar.gz",
    ],
)

git_repository(
    name = "com_github_bazelbuild_buildtools",
    commit = "c802c3b06ba674e8a76d04c0677d153ab9f660c9",  #v5.1.0
    remote = "https://github.com/bazelbuild/buildtools.git",
    shallow_since = "1649877303 +0200",
)

git_repository(
    name = "com_google_protobuf",
    commit = "f0dc78d7e6e331b8c6bb2d5283e06aa26883ca7c",  #v21.12
    remote = "https://github.com/protocolbuffers/protobuf.git",
    shallow_since = "1670889792 -0800",
)

# Stardoc is a documentation generator for Bazel
git_repository(
    name = "io_bazel_stardoc",
    commit = "50cb91505b14b1dd07e32eb6145c5767b7a629c7",  #v0.5.3
    remote = "https://github.com/bazelbuild/stardoc.git",
    shallow_since = "1664546324 -0400",
)

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@com_github_bazelbuild_buildtools//buildifier:deps.bzl", "buildifier_dependencies")
load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
load("//gotemplate:deps.bzl", "gotemplate_dependencies")

go_rules_dependencies()

go_register_toolchains("1.19.4")

gazelle_dependencies()

buildifier_dependencies()

gotemplate_dependencies()

protobuf_deps()
