# Image composition

[`recipes/recipe.yml`](../recipes/recipe.yml) is the image definition and the
main source of truth. This document explains what that recipe puts into the
image and where those packages come from.

## Package sources

| Repository | Used for |
|---|---|
| Fedora 44 | everything not listed below |
| [Terra](https://wiki.fyralabs.com/Terra) | `umbriel-nightly`, `noctalia-greeter`, `xdg-desktop-portal-umbriel-nightly`, `starship`, `zsh-autocomplete` |
| [Tailscale](https://pkgs.tailscale.com/stable/fedora/) | `tailscale`, which runs a few releases ahead of Fedora's |
| [COPR: lihaohong/yazi](https://copr.fedorainfracloud.org/coprs/lihaohong/yazi) | `yazi` and `resvg`, which Fedora does not package |
| [Universal Blue](https://github.com/ublue-os/akmods) | the prebuilt kernel modules |
| Flathub | the system and user Flatpaks |

Terra is added by the `dnf` module from `files/dnf/terra-44.repo`. Its file
name carries the Fedora release, so the recipe refers to it as
`terra-%OS_VERSION%.repo` — bumping `image-version` in the recipe means
renaming that file too, and the build fails loudly until you do.

The Noctalia shell itself is in Fedora as well, and Fedora's build is the
newer one (`5.3.0` against Terra's `5.0.0~beta.9`), so that is the one dnf
picks. Terra is only needed for the compositor, the greeter, the portal and
the shell tools.

Terra also carries `starship`, the prompt, and `zsh-autocomplete`, the
type-ahead completion. Neither is in Fedora, and both are used by the
command shell the image sets up.

Tailscale's repository is added from `files/dnf/tailscale.repo`, a copy of
Tailscale's own with `skip_if_unavailable` set, so an outage there falls back
to Fedora's copy instead of failing the build.

Yazi is not packaged in Fedora at all. It comes from the unofficial COPR that
the yazi documentation points at, added from `files/dnf/yazi.repo`. That
repository builds yazi and `resvg` for every Fedora release, and its base URL
carries `$releasever`, so it follows the base image's release without the
file having to be renamed. Unlike Tailscale's, it has no `skip_if_unavailable`:
there is no Fedora package to fall back to, so an outage has to fail the
build instead of producing an image without a file manager.

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
