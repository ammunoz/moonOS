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
| Terminal | `kitty` |
| File manager | `yazi` — a terminal file manager with image previews |
| Editor | `micro` — the default editor, also aliased as `nano` and `rnano` |
| Kernel modules | `xone`, `xpadneo`, `v4l2loopback`, `openrazer`, `wl` |
| Fonts | Cantarell, Noto Sans/Serif/Mono, Noto Color Emoji, plus Inter and JetBrains Mono (a Nerd Font) |
| Desktop extras | `file-roller` (archives), `pavucontrol` (audio mixer), `seahorse` (Passwords and Keys), `ddcutil` (external monitor brightness) |
| Preview tools | `poppler-utils` (PDF), `ImageMagick` (fonts, HEIC, JXL), `ffmpeg-free` (video), `resvg` (SVG) |
| Flatpaks (system) | Flatseal, Calculator, Document Viewer, Image Viewer, Music |
| Flatpaks (user) | Betterbird, Bitwarden, Discord, Heroic, Krita, LibreOffice, LibreWolf, mpv, OBS Studio, Spotify, Steam, Zoom |
| Replaced | `nano` and `vim` with `micro`; `firefox` with the LibreWolf Flatpak |

`EDITOR`, `VISUAL` and `GIT_EDITOR` are set to `micro` for both systemd
sessions and login shells. There is no `vi` on this image, so anything that
shells out to an editor needs one of those three variables set.

## Flatpak scopes

Flatpaks are installed in two passes:

| Scope | When |
|---|---|
| system | during boot, once, for every user |
| user | on the **first login** of each user |

The browser (LibreWolf), Steam, OBS Studio, Discord and the rest are user
scope, so they arrive after you log in the first time — not at first boot.

## The terminal and the file manager

The terminal is **kitty**, and the file manager is **yazi**, which runs inside
it. yazi renders its previews with kitty's graphics protocol, so images,
SVGs, PDFs, videos, fonts and archives all preview in the preview pane
without leaving the terminal.

`kitty` is configured system-wide in `/etc/xdg/kitty/kitty.conf`: the JetBrains
Mono Nerd Font that the image installs, a Nord colour scheme that matches
yazi's theme, and <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>I</kbd> to show an
image in the terminal. A user's own `~/.config/kitty/kitty.conf` overrides it.

`yazi` is configured with `/etc/skel/.config/yazi/`, which is copied into
every **new** account. It is a small file: yazi merges it over its own
defaults, so it only carries what moonOS changes — a wider preview pane, micro
as the editor fallback (there is no `vi` on this image) and an *Open in a new
window* action for the files you select.

To take the same configuration on an account that already exists:

```bash
cp -r /etc/skel/.config/yazi ~/.config/
```

## Opening files

The image has default applications for the file types it can handle, in
`/etc/xdg/mimeapps.list`:

| Type | Opens with |
|---|---|
| Images | Image Viewer (Loupe) |
| PDF and EPUB | Document Viewer (Evince) |
| Audio and video | mpv |
| Archives | Archive Manager (file-roller) |
| Office documents | LibreOffice |
| Web pages | LibreWolf |
| Text and code | micro, in a kitty window |
| Folders | yazi, in a kitty window |

The Flatpaks in the first six rows are installed with the image or on the
first login, so the association starts working once the Flatpak in question
is there. A user can override any of it in `~/.config/mimeapps.list`.

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

> The image used to be published to `git.ajiky.com/iky/moonos`. That
> registry is gone, so a rebase pointing at it has to be pointed at
> `ghcr.io/ammunoz/moonos` instead.

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

## Passwords and the keyring

The shell stores the encryption key for its clipboard history and calendar
cache in the desktop Secret Service, which `gnome-keyring` provides. Password
quality for local accounts is already enforced by `pam_pwquality`.

**Check this on the first login.** Open *Passwords and Keys* (`seahorse`) and
make sure the **Login** keyring is the default:

- If a different keyring is the default, the shell cannot read its clipboard
  history or calendar credentials until a second login unlocks it.
- The symptom is subtle — the clipboard panel is empty after every reboot, and
  the calendar never appears.

## Configuration on the image

| What | Where |
|---|---|
| Umbriel compositor | `/usr/etc/xdg/umbriel/config.toml` — system-wide default, users can override it in `~/.config/umbriel/config.toml` |
| Terminal | `/etc/xdg/kitty/kitty.conf` — system-wide kitty configuration, users can override it in `~/.config/kitty/kitty.conf` |
| Terminal variable | `/usr/lib/environment.d/95-terminal.conf` and `/etc/profile.d/terminal.sh` — set `TERMINAL=kitty` |
| Default applications | `/etc/xdg/mimeapps.list` — which application opens which file type |
| Default terminal | `/etc/xdg/xdg-terminals.list` — kitty, for applications that ask `xdg-terminal-exec` |
| File manager | `/etc/skel/.config/yazi/` — copied into every new account, and overridden by the user's own config |
| Shell defaults | `/etc/skel/.config/noctalia/00-moonos.toml` — copied into every new account, and overridden by the user's own config |
| Noctalia shell | `~/.config/noctalia/config.toml` — the shell reads every `*.toml` in that directory |
| Noctalia state | `~/.local/state/noctalia/settings.toml` — written by the settings UI, do not edit by hand |
| Wi-Fi backend | `/etc/NetworkManager/conf.d/99-wifi-backend.conf` — written at boot by `moonos-wifi-backend.service` |
| Greeter account | `greeter`, created by `systemd-sysusers` on every boot |
| Editor variables | `/usr/lib/environment.d/90-micro-editor.conf` and `/etc/profile.d/micro.sh` |
| Kernel module key | `/etc/pki/akmods/certs/akmods-ublue.der` — enrolled in the MOK on first boot |

The Wi-Fi backend is chosen automatically: `iwd` when every wireless device on
the machine is an Intel one, `wpa_supplicant` otherwise. Both are installed.

## Known limitations

- **User-scope Flatpaks arrive on the first login**, not at first boot. The
  file types that they handle — web pages, video, office documents — have no
  application until then.
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
