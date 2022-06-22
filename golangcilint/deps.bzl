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

_VERSION = "1.46.2"
_CHECKSUMS = {
    "windows-386": "b48a421ec12a43f8fc8f977b9cf7d4a1ea1c4b97f803a238de7d3ce4ab23a84b",
    "windows-amd64": "604acc1378a566abb0eac799362f3a37b7fcb5fa2268aeb2d5d954c829367301",
    "linux-amd64": "242cd4f2d6ac0556e315192e8555784d13da5d1874e51304711570769c4f2b9b",
    "linux-386": "461a60016d516c69d406dc3e2d4957b722dbe684b7085dfac4802d0f84409e27",
    "darwin-amd64": "658078aaaf7608693f37c4cf1380b2af418ab8b2d23fdb33e7e2d4339328590e",
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
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.2/bazel-skylib-1.0.2.tar.gz",
        ],
        sha256 = "97e70364e9249702246c0e9444bccdc4b847bed1eb03c5a3ece4f83dfe6abc44",
    )
    _golangcilint_download(
        name = "com_github_ash2k_bazel_tools_golangcilint",
    )
