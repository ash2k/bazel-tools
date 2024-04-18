load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_DOWNLOAD_URI = (
    "https://github.com/golangci/golangci-lint/releases/download/v{version}/" +
    "golangci-lint-{version}-{arch}.{archive}"
)
_PREFIX = (
    "golangci-lint-{version}-{arch}"
)

_ARCHIVE_TYPE = ["zip", "tar.gz"]

_VERSION = "v1.57.2"
_CHECKSUMS = {
    "windows-386": "95321b1ec07db22e29538d0b18d36a376ca7d834c4826351db2b73436d27f7c1",
    "windows-amd64": "10c1ab7eb4a99f8b292a8f910bc78a50e9547a4ffe7444fcddc68f722adf6612",
    "linux-amd64": "391483daa5d58d037832ba2fac709fdb5df0c67471c0d7698d1f67cbfa5f10f0",
    "linux-386": "51694b9b9da783f70fb4060403cd476f7e77509bbbfeda222994a0ec3c43a8f8",
    "darwin-amd64": "83157f5378d259d51c88e310e88513bd80bd42e497974a1bbe51b82931f229c7",
}

def _golangcilint_download_impl(ctx):
    if ctx.os.name == "linux":
        arch = "linux-amd64"
    elif ctx.os.name == "mac os x":
        arch = "darwin-amd64"
    else:
        fail("Unsupported operating system: {}".format(ctx.os.name))

    if arch not in _CHECKSUMS:
        fail("Unsupported arch {}".format(arch))

    if arch.startswith("windows"):
        archive = _ARCHIVE_TYPE[0]
    else:
        archive = _ARCHIVE_TYPE[1]

    url = _DOWNLOAD_URI.format(version = _VERSION, arch = arch, archive = archive)
    prefix = _PREFIX.format(version = _VERSION, arch = arch)
    sha256 = _CHECKSUMS[arch]

    ctx.template(
        "BUILD.bazel",
        Label("@com_github_ash2k_bazel_tools//golangcilint:golangcilint.build.bazel"),
        executable = False,
    )
    ctx.download_and_extract(
        stripPrefix = prefix,
        url = url,
        sha256 = sha256,
    )

_golangcilint_download = repository_rule(
    implementation = _golangcilint_download_impl,
)

def golangcilint_dependencies():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        ],
    )
    _golangcilint_download(
        name = "com_github_ash2k_bazel_tools_golangcilint",
    )
