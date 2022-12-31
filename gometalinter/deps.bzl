load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_GOMETALINTER_TARBALLS = {
    "darwin_amd64": (
        "gometalinter-2.0.10-darwin-amd64.tar.gz",
        "gometalinter-2.0.10-darwin-amd64",
        "b21c28a236f05d1cd1a394240388afdc3a20a2ddfeb34acb19c651d5d1936523",
    ),
    "linux_amd64": (
        "gometalinter-2.0.10-linux-amd64.tar.gz",
        "gometalinter-2.0.10-linux-amd64",
        "111f656a8599349168544b9ae0dbc93240edcb28a81a92e9810ceaa40575545a",
    ),
}

def _gometalinter_download_impl(ctx):
    if ctx.os.name == "linux":
        host = "linux_amd64"
    elif ctx.os.name == "mac os x":
        host = "darwin_amd64"
    else:
        fail("Unsupported operating system: " + ctx.os.name)
    if host not in _GOMETALINTER_TARBALLS:
        fail("Unsupported host {}".format(host))

    filename, prefix, sha256 = _GOMETALINTER_TARBALLS[host]
    url = "https://github.com/alecthomas/gometalinter/releases/download/v2.0.10/" + filename

    ctx.template(
        "BUILD.bazel",
        Label("@com_github_ash2k_bazel_tools//gometalinter:gometalinter.build.bazel"),
        executable = False,
    )
    ctx.download_and_extract(
        stripPrefix = prefix,
        url = url,
        sha256 = sha256,
    )

_gometalinter_download = repository_rule(
    implementation = _gometalinter_download_impl,
)

def gometalinter_dependencies():
    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "74d544d96f4a5bb630d465ca8bbcfe231e3594e5aae57e1edbf17a6eb3ca2506",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.3.0/bazel-skylib-1.3.0.tar.gz",
        ],
    )
    _gometalinter_download(
        name = "com_github_ash2k_bazel_tools_gometalinter",
    )
