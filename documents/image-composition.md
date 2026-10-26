# Image composition

[`recipes/recipe.yml`](../recipes/recipe.yml) is the image definition and the
main source of truth. This document explains what that recipe puts into the
image and where those packages come from.

## Package sources

| Repository | Used for |
|---|---|
| Fedora 44 | everything not listed below |
| [Terra](https://wiki.fyralabs.com/Terra) | `noctalia`, `umbriel-nightly`, `noctalia-greeter`, `xdg-desktop-portal-umbriel-nightly` |
| [Tailscale](https://pkgs.tailscale.com/stable/fedora/) | `tailscale`, which runs a few releases ahead of Fedora's |
| [Universal Blue](https://github.com/ublue-os/akmods) | the prebuilt kernel modules |
| Flathub | the system Flatpaks |

Terra is added by the `dnf` module from `files/dnf/terra-44.repo`. Its file
name carries the Fedora release, so the recipe refers to it as
`terra-%OS_VERSION%.repo` — bumping `image-version` in the recipe means
renaming that file too, and the build fails loudly until you do.

Tailscale's repository is added from `files/dnf/tailscale.repo`, a copy of
Tailscale's own with `skip_if_unavailable` set, so an outage there falls back
to Fedora's copy instead of failing the build.

Umbriel only exists as a nightly build (`umbriel-nightly`); there is no stable
release yet, so it will churn between builds.

## Repository layout

```
recipes/recipe.yml   the image definition — this is the main source of truth
files/               build-time file drops and scripts
modules/akmods/      the kernel module installer, a local BlueBuild module
documents/           the contributor documentation
.github/             CI workflow and Renovate config
scripts/             CI helper scripts
cosign.pub           the public half of the image signing key
CODEOWNERS           repository owners
```

The `files/` directory is documented in
[`files/README.md`](../files/README.md): which files end up where in the
image, how the `files`, `script` and `systemd` modules read them, and what the
`/etc` to `/usr/etc` split means on an ostree system.

The kernel module installer in `modules/akmods/` is covered in
[kernel-modules.md](kernel-modules.md).

## See also

- [kernel-modules.md](kernel-modules.md) — the prebuilt kernel modules
- [customising.md](customising.md) — changing what goes into the image
- [building.md](building.md) — how the image gets built and published
