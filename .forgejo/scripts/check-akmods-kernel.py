#!/usr/bin/env python3
"""Check that the base image kernel matches Universal Blue's akmods bundle.

BlueBuild derives Universal Blue's kernel-module bundle from the Fedora
version of the base image, and that bundle only contains modules built for
one exact kernel. If the base image has moved on to a newer kernel than the
bundle was built for, the modules cannot be installed.

This check runs before the image build so that a mismatch stops the build
instead of producing an image that is missing its kernel modules.

Exits 0 when the kernels match, 1 otherwise.
"""

import json
import pathlib
import sys
import urllib.error
import urllib.request

MANIFEST_ACCEPT = ", ".join(
    [
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.docker.distribution.manifest.list.v2+json",
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.docker.distribution.manifest.v2+json",
    ]
)

TOKEN_ENDPOINTS = {
    "ghcr.io": "https://ghcr.io/token?scope=repository:{repo}:pull&service=ghcr.io",
    "quay.io": "https://quay.io/v2/auth?service=quay.io&scope=repository:{repo}:pull",
}

ROOT = pathlib.Path(__file__).resolve().parents[2]
RECIPE = ROOT / "recipes" / "recipe.yml"

AKMODS_REPOSITORY = "ghcr.io/ublue-os/akmods"
KERNEL_LABEL = "ostree.linux"
VERSION_LABEL = "org.opencontainers.image.version"


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def split_ref(ref):
    """Split "ghcr.io/owner/name:tag" into ("ghcr.io", "owner/name", "tag")."""
    registry, _, rest = ref.partition("/")
    if ":" in rest.rsplit("/", 1)[-1]:
        repo, _, tag = rest.rpartition(":")
    else:
        repo, tag = rest, "latest"
    return registry, repo, tag


def fetch(url, token=None, accept=None):
    headers = {}
    if token:
        headers["Authorization"] = "Bearer " + token
    if accept:
        headers["Accept"] = accept
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def token_for(registry, repo):
    template = TOKEN_ENDPOINTS.get(registry)
    if not template:
        return None
    with urllib.request.urlopen(template.format(repo=repo), timeout=60) as response:
        payload = json.load(response)
    return payload.get("token") or payload.get("access_token")


def image_labels(ref):
    """Return the labels of an image, without downloading any layers."""
    registry, repo, tag = split_ref(ref)
    try:
        token = token_for(registry, repo)
        base = f"https://{registry}/v2/{repo}"

        manifest = json.loads(fetch(f"{base}/manifests/{tag}", token, MANIFEST_ACCEPT))
        if "manifests" in manifest:
            chosen = None
            for entry in manifest["manifests"]:
                platform = entry.get("platform") or {}
                if platform.get("os") == "linux" and platform.get("architecture") == "amd64":
                    chosen = entry
                    break
            if chosen is None:
                raise RuntimeError(f"no linux/amd64 manifest in {ref}")
            manifest = json.loads(
                fetch(f"{base}/manifests/{chosen['digest']}", token, MANIFEST_ACCEPT)
            )

        config = json.loads(fetch(f"{base}/blobs/{manifest['config']['digest']}", token))
    except urllib.error.URLError as error:
        raise RuntimeError(f"could not read {ref}: {error}") from error
    except (KeyError, ValueError) as error:
        raise RuntimeError(f"unexpected registry response for {ref}: {error}") from error

    return (config.get("config") or {}).get("Labels") or {}


def recipe_value(path, key):
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            if line.startswith(key + ":"):
                return line.split(":", 1)[1].strip().strip("\"'")
    return None


def akmods_base(path):
    """The `base:` of the akmods module, which selects the bundle flavour."""
    base = "main"
    in_akmods = False
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped.startswith("- type:"):
                in_akmods = stripped.split(":", 1)[1].strip() == "akmods"
            elif in_akmods and stripped.startswith("base:"):
                base = stripped.split(":", 1)[1].strip().strip("\"'")
    return base


def main():
    if not RECIPE.is_file():
        fail(f"{RECIPE} not found")

    base_image = recipe_value(RECIPE, "base-image")
    image_version = recipe_value(RECIPE, "image-version")
    if not base_image or not image_version:
        fail("could not read base-image and image-version from the recipe")

    base_ref = f"{base_image}:{image_version}"
    print(f"base image: {base_ref}")

    try:
        base_labels = image_labels(base_ref)
    except RuntimeError as error:
        fail(str(error))

    image_kernel = base_labels.get(KERNEL_LABEL)
    version_label = base_labels.get(VERSION_LABEL, "")
    major = version_label.split(".")[0]

    if not image_kernel or not major.isdigit():
        fail(
            f"the base image does not carry a usable {KERNEL_LABEL} or "
            f"{VERSION_LABEL} label"
        )

    bundle_ref = f"{AKMODS_REPOSITORY}:{akmods_base(RECIPE)}-{major}"
    print(f"akmods bundle: {bundle_ref}")

    try:
        bundle_labels = image_labels(bundle_ref)
    except RuntimeError as error:
        fail(str(error))

    bundle_kernel = bundle_labels.get(KERNEL_LABEL)
    if not bundle_kernel:
        fail(f"{bundle_ref} does not carry a {KERNEL_LABEL} label")

    print(f"image kernel:   {image_kernel}")
    print(f"bundle kernel:  {bundle_kernel}")

    if image_kernel != bundle_kernel:
        print(
            "error: the base image kernel and the akmods bundle kernel differ.\n"
            "       Universal Blue has not rebuilt the bundle for this kernel yet,\n"
            "       so the kernel modules cannot be installed. Refusing to build.",
            file=sys.stderr,
        )
        sys.exit(1)

    print("kernels match, the build can go ahead")


if __name__ == "__main__":
    main()
