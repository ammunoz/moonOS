# moonOS

A custom **Fedora Atomic** desktop image built with
[BlueBuild](https://blue-build.org): the [Noctalia](https://noctalia.dev)
desktop shell running on the [Umbriel](https://github.com/noctalia-dev/umbriel)
Wayland compositor, with the Noctalia greeter as the login screen.

The image is published to `ghcr.io/ammunoz/moonos`.

## What's in it

| | |
|---|---|
| Base | `ghcr.io/blue-build/base-images/fedora-base` (Fedora **44**) |
| Shell | `noctalia` — Noctalia desktop shell |
| Compositor | `umbriel-nightly` — Umbriel Wayland compositor |
| Login | `greetd` + `noctalia-greeter` |
| Terminal | `foot` |
| Editor | `micro` — the default editor, also aliased as `nano` and `rnano` |
| Kernel modules | `xone`, `xpadneo`, `v4l2loopback`, `openrazer`, `wl` |
| Flatpaks | `io.gitlab.librewolf-community`, `org.gnome.Loupe`, `com.valvesoftware.Steam` (system scope) |
| Replaced | `nano` and `vim` with `micro`; `firefox` with the LibreWolf Flatpak |

`EDITOR`, `VISUAL` and `GIT_EDITOR` are set to `micro` for both systemd
sessions and login shells. There is no `vi` on this image, so anything that
shells out to an editor needs one of those three variables set.

## Kernel modules

The kernel modules are prebuilt by Universal Blue for the exact kernel of the
base image, so the image needs neither a compiler nor `kernel-devel`.

| Module | For |
|---|---|
| `xone` | Xbox One controllers over USB |
| `xpadneo` | Xbox One controllers over Bluetooth |
| `v4l2loopback` | virtual cameras |
| `openrazer` | Razer devices (with the daemon from Terra) |
| `wl` | Broadcom wireless cards |

The bundle is built for one kernel at a time, so the build checks that the
base image and the bundle agree before it starts. If they disagree the build
stops rather than publishing an image that is missing its modules.

### Secure Boot

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

## Installing

There are two supported ways to get moonOS onto a machine.

### 1. Rebase an existing Atomic Fedora installation

This is the quickest path if you already run Fedora Atomic. The user account
you have stays as it is; `initial-setup` sees that the account is already
configured and does nothing.

```bash
# first rebase to the unsigned image, to get the proper signing keys and policies installed
rpm-ostree rebase ostree-unverified-registry:ghcr.io/ammunoz/moonos:latest
systemctl reboot
```

```bash
# then rebase to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ammunoz/moonos:latest
systemctl reboot
```

The `latest` tag automatically points at the most recent build from the
default branch. That build will still always use the Fedora version specified
in `recipe.yml`, so you won't get accidentally updated to the next major
version.

Those builds are also published under their Fedora version (`:44` for the
current one), so you can pin to that instead of `latest` if you want to stay on
a specific release.

### 2. Install from an ISO

If you build on Fedora Atomic, you can generate an offline ISO using the
[instructions here](https://blue-build.org/how-to/generate-iso/). These ISOs
cannot be distributed on GitHub for free due to their size, so for public
projects something else has to be used for hosting.

Anaconda creates the user account during the installation, so `initial-setup`
has nothing left to do on the first boot.

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
cosign verify --key cosign.pub ghcr.io/ammunoz/moonos:latest
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
  next build, which is at most a day away.
- **Umbriel is nightly-only.** Expect compositor behaviour to change between
  builds.

## Development

This README is for people using moonOS. If you want to change it, the
contributor documentation lives in [`documents/`](documents/):

- [image-composition.md](documents/image-composition.md) — what goes into the image and where it comes from
- [kernel-modules.md](documents/kernel-modules.md) — the prebuilt kernel modules
- [building.md](documents/building.md) — CI, secrets, published tags, local builds
- [customising.md](documents/customising.md) — changing the image
- [upstream-template.md](documents/upstream-template.md) — syncing with the upstream BlueBuild template
