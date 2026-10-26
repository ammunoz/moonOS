# Contributor documentation

The [root README](../README.md) is for people who want to use moonOS: what
the image contains, how to install it, how to verify it. These documents are
for people who change it.

| Document | Covers |
|---|---|
| [image-composition.md](image-composition.md) | what goes into the image, where those packages come from, and the repository layout |
| [kernel-modules.md](kernel-modules.md) | the prebuilt kernel modules, the akmods module and the kernel-match check |
| [building.md](building.md) | CI, required secrets, published image tags and local builds |
| [customising.md](customising.md) | changing the packages, files and base image of moonOS |
| [upstream-template.md](upstream-template.md) | staying in sync with the upstream BlueBuild template |

The `files/` directory has its own README for the build-time file drops:
[`files/README.md`](../files/README.md).
