# moonOS

A custom **Fedora Atomic** desktop image built with
[BlueBuild](https://blue-build.org): the [Noctalia](https://noctalia.dev)
desktop shell running on the [Umbriel](https://github.com/noctalia-dev/umbriel)
Wayland compositor, with the Noctalia greeter as the login screen.

The image is published to this Forgejo instance's container registry at
`git.ajiky.com/iky/moonos`.

## What's in it

| | |
|---|---|
| Base | `ghcr.io/blue-build/base-images/fedora-base` (Fedora **44**) |
| Shell | `noctalia` — Noctalia desktop shell |
| Compositor | `umbriel-nightly` — Umbriel Wayland compositor |
| Login | `greetd` + `noctalia-greeter` |
| Terminal | `foot` |
| Editor | `micro`, with `micro-default-editor` claiming `system-default-editor` (also aliased as `nano` and `rnano`) |
| Kernel modules | `xone`, `xpadneo`, `v4l2loopback`, `openrazer`, `wl` |
| First boot | `initial-setup` creates the user account |
| Flatpaks | `io.gitlab.librewolf-community`, `org.gnome.Loupe`, `com.valvesoftware.Steam` (system scope) |
| Removed | `firefox` and `firefox-langpacks` RPMs, in favour of the LibreWolf Flatpak |
| Removed | `nano`, `nano-default-editor` and all `vim-*` packages |
| Signing | cosign key pair, verified on rebase |

`EDITOR`, `VISUAL` and `GIT_EDITOR` are set to `micro` for both systemd
sessions and login shells. There is no `vi` on this image, so anything that
shells out to an editor needs one of those three variables set.

### Where the packages come from

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

### Kernel modules

The kernel modules are prebuilt by Universal Blue for the exact kernel of the
base image, so the image needs neither a compiler nor `kernel-devel`. BlueBuild
stages their bundle automatically for any module of type `akmods`; the recipe
uses that module type with `source: local` so that
[`modules/akmods/akmods.sh`](modules/akmods/akmods.sh) does the install with
`dnf5` instead of the built-in script.

| Module | For |
|---|---|
| `xone` | Xbox One controllers over USB |
| `xpadneo` | Xbox One controllers over Bluetooth |
| `v4l2loopback` | virtual cameras |
| `openrazer` | Razer devices (with the daemon from Terra) |
| `wl` | Broadcom wireless cards |

The bundle is built for one kernel at a time, so the build checks that the
base image and the bundle agree before it starts — see
[Building](#building). If they disagree the build stops rather than
publishing an image that is missing its modules.

#### Secure Boot

The modules are signed with Universal Blue's key, which a Secure Boot system
has to trust before the kernel will load them. moonOS ships the certificate
at `/etc/pki/akmods/certs/akmods-ublue.der` and stages it for enrolment on
first boot:

```bash
sudo /usr/libexec/moonos/enroll-akmods-key
```

That writes the key into the machine's MOK. **Reboot and choose "Enroll MOK"
in the MOK Manager** — that last step happens in the firmware, before the
kernel starts, so it cannot be done for you. On a system without Secure Boot
the modules load straight away and none of this is needed.

## Layout

```
recipes/recipe.yml   the image definition — this is the main source of truth
files/               optional build-time file drops and scripts (see files/README.md)
modules/akmods/      the kernel module installer, a local BlueBuild module
.forgejo/scripts/    CI helper scripts
cosign.pub           the public half of the image signing key
CODEOWNERS           repository owners
```

## Required secrets

Set these in the repository's **Settings → Secrets** on `git.ajiky.com`:

| Secret | Value |
|---|---|
| `SIGNING_SECRET` | the cosign **private** key (PEM). Must match the committed `cosign.pub`. |
| `REGISTRY_TOKEN` | a Forgejo personal access token with the `write:package` scope, used to push to `git.ajiky.com`. |

The private key is never committed — `.gitignore` excludes `cosign.key` and
`cosign.private`.

## Building

Pushes to `main`, pull requests, and a daily schedule at 06:00 UTC all trigger
a build. Every run first validates `recipes/recipe.yml` against the published
JSON schema, then checks that the base image and the kernel-module bundle are
built for the same kernel, then builds and pushes the image.

The kernel check is [`.forgejo/scripts/check-akmods-kernel.py`](.forgejo/scripts/check-akmods-kernel.py).
It reads the `ostree.linux` label of the base image and of Universal Blue's
bundle and compares the two. When they differ the build stops with an error
rather than publishing an image whose kernel modules cannot be installed —
the bundle is rebuilt daily, so the next run picks the new one up. You can run
the check yourself at any time:

```bash
python3 .forgejo/scripts/check-akmods-kernel.py
```

The image is pushed with these tags, where `<fedora>` is the Fedora version of
the base image the build used (currently `44`):

- `latest` — the most recent build from the default branch
- `<fedora>` — e.g. `44`
- `<timestamp>` and `<timestamp>-<fedora>`
- `<short-sha>-<fedora>`

### Building locally

```bash
bluebuild build -v recipes/recipe.yml
```

See the [BlueBuild local build guide](https://blue-build.org/how-to/local/).
A local build does not push; add `--push` plus `--registry`/`--username`/
`--password` to publish.

## Installing

There are two supported ways to get moonOS onto a machine.

### 1. Rebase an existing Atomic Fedora installation

This is the quickest path if you already run Fedora Atomic. The user account
you have stays as it is; `initial-setup` sees that the account is already
configured and does nothing.

```bash
# first rebase to the unsigned image, to get the proper signing keys and policies installed
rpm-ostree rebase ostree-unverified-registry:git.ajiky.com/iky/moonos:latest
systemctl reboot
```

```bash
# then rebase to the signed image
rpm-ostree rebase ostree-image-signed:docker://git.ajiky.com/iky/moonos:latest
systemctl reboot
```

The `latest` tag will automatically point to the latest build. That build will
still always use the Fedora version specified in `recipe.yml`, so you won't get
accidentally updated to the next major version.

### 2. Install from an ISO

If you build on Fedora Atomic, you can generate an offline ISO using the
[instructions here](https://blue-build.org/how-to/generate-iso/). These ISOs
cannot be distributed on GitHub for free due to their size, so for public
projects something else has to be used for hosting.

Anaconda creates the user account during the installation, so `initial-setup`
has nothing left to do on the first boot.

> **Private registry caveat:** the installer pulls the container image from
> `git.ajiky.com` at install time, and that registry needs authentication.
> Until the image is published somewhere public, use the rebase path above or
> provide the registry credentials to the installer.

### First boot on a bare machine

Installing the container onto a machine without an account (`rpm-ostree
install`) leaves you without a user, which is what `initial-setup` is for: it
starts a text wizard on `tty7` before the greeter appears and lets you create
the account, set the time zone and set the root password. It disables itself
after it has run.

## Verifying the signature

Images are signed with [Sigstore](https://www.sigstore.dev/)'s
[cosign](https://github.com/sigstore/cosign). Verify with the `cosign.pub`
file from this repository:

```bash
cosign verify --key cosign.pub git.ajiky.com/iky/moonos:latest
```

## Configuration on the image

| What | Where |
|---|---|
| Umbriel compositor | `/usr/etc/xdg/umbriel/config.toml` — system-wide default, users can override it in `~/.config/umbriel/config.toml` |
| Wi-Fi backend | `/etc/NetworkManager/conf.d/99-wifi-backend.conf` — written at boot by `moonos-wifi-backend.service` |
| Greeter account | `greeter`, created by `systemd-sysusers` on every boot |
| Editor variables | `/usr/lib/environment.d/90-micro-editor.conf` and `/etc/profile.d/micro.sh` |
| Kernel module key | `/etc/pki/akmods/certs/akmods-ublue.der` — enrolled in the MOK on first boot |

The Wi-Fi backend is chosen automatically: `iwd` when every wireless device on
the machine is an Intel one, `wpa_supplicant` otherwise. Both are installed.

## Known limitations

- **No NVIDIA driver.** The image ships the standard Mesa stack only.
- **No `nct6687d`.** Universal Blue builds that module in their `extra`
  bundle, which is not published for Fedora's mainline kernel, and Fedora
  only ships it as a source package that has to be compiled against the
  running kernel.
- **The kernel modules need a matching kernel.** They are prebuilt for one
  kernel at a time, so they are tied to the base image's kernel. A rebase
  brings the matching modules with it, but a kernel that moved on before
  Universal Blue rebuilt the bundle leaves the image without them until the
  next build.
- **Umbriel is nightly-only.** Expect compositor behaviour to change between
  builds.

## Customising

Edit `recipes/recipe.yml` — it is validated on every pull request, so mistakes
are caught before a build starts.

- **Packages**: add to the `dnf` module's `install.packages` list. Anything in
  Fedora's repositories works without extra configuration. Third-party repos go
  under `repos.files` and `repos.keys`.
- **Files and scripts**: see [`files/README.md`](files/README.md).
- **Base image**: `image-version` accepts `latest` or a Fedora major version
  (e.g. `44`). Pinning a major version freezes your base, but note that the
  pinned tag is removed from the base image when that release ages out, so
  a stale pin will eventually break the build.

## Staying current with the template

This repository started as a fork of
[blue-build/template](https://github.com/blue-build/template/). The upstream
template changes rarely, and it explicitly states that syncing is not required
to keep the repository functional. The parts that do change are:

- the `blue-build/github-action` version — tracked automatically by
  [Renovate](.forgejo/renovate.json), which understands the SHA-pinned
  `uses:` reference in [`.forgejo/workflows/build.yml`](.forgejo/workflows/build.yml)
- `recipes/recipe.yml` and `README.md` defaults — applied by hand
- `.gitignore` — applied by hand

To see what upstream has changed:

```bash
git remote add template https://github.com/blue-build/template.git
git fetch template
git diff main template/main
```
