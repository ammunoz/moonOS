# `files/`

Drop-in directories that BlueBuild modules read at build time.

```
files/
├── dnf/
│   ├── tailscale.repo            Tailscale's repository
│   ├── terra-44.repo             the Terra repository definition
│   └── yazi.repo                 the COPR the yazi file manager comes from
├── system/                       copied into the image root
│   ├── etc/
│   │   ├── profile.d/
│   │   │   ├── micro.sh
│   │   │   └── terminal.sh
│   │   ├── skel/
│   │   │   ├── .config/
│   │   │   │   ├── noctalia/
│   │   │   │   │   └── 00-moonos.toml
│   │   │   │   └── yazi/
│   │   │   │       ├── theme.toml
│   │   │   │       └── yazi.toml
│   │   │   └── .zshrc
│   │   ├── xdg/
│   │   │   ├── kitty/
│   │   │   │   └── kitty.conf
│   │   │   ├── mimeapps.list
│   │   │   ├── umbriel/
│   │   │   │   └── config.toml
│   │   │   └── xdg-terminals.list
│   │   └── zsh/
│   │       └── moonos.zsh
│   └── usr/
│       ├── lib/
│       │   ├── environment.d/
│       │   │   ├── 90-micro-editor.conf
│       │   │   └── 95-terminal.conf
│       │   ├── sysusers.d/
│       │   │   └── noctalia-greeter.conf
│       │   └── tmpfiles.d/
│       │       └── noctalia-greeter.conf
│       ├── libexec/
│       │   └── moonos/
│       │       ├── enroll-akmods-key
│       │       └── select-wifi-backend
│       └── share/
│           ├── applications/
│           │   ├── moonos-micro.desktop
│           │   └── moonos-yazi.desktop
│           └── moonos/
│               └── starship.toml
└── systemd/
    └── system/
        ├── moonos-akmods-key.service
        ├── moonos-greeter-setup.service
        └── moonos-wifi-backend.service
```

## `files/system/` — copied into the image

Everything under `files/system/` is copied to the root of the image (`/`) by
the [`files` module](https://blue-build.org/reference/modules/files/).

Enable it in `recipes/recipe.yml`:

```yaml
modules:
  - type: files
    files:
      - source: system
        destination: /
```

Two things to know:

- `/etc` at build time becomes `/usr/etc` at runtime, which is where Atomic
  Fedora keeps system configuration. Files you need at the *real* `/etc` have
  to be written by the [`script` module](https://blue-build.org/reference/modules/script/).
- Do not copy into `/home`, `/opt`, `/srv`, `/root`, `/usr/local`, `/mnt` or
  `/tmp` — `rpm-ostree` symlinks those directories, and the `files` module
  cannot write to them.

### What is currently in the image

| File | Purpose |
|---|---|
| `etc/profile.d/micro.sh` | sets `EDITOR`/`VISUAL`/`GIT_EDITOR` to `micro` for login shells |
| `etc/profile.d/terminal.sh` | sets `TERMINAL=kitty` for login shells |
| `etc/skel/.config/noctalia/00-moonos.toml` | Noctalia defaults copied into every new account: DDC/CI brightness for external monitors |
| `etc/skel/.config/yazi/` | the yazi defaults copied into every new account: a wider preview pane, micro as the editor, *Open in a new window* |
| `etc/skel/.zshrc` | zsh defaults copied into every new account: the history settings |
| `etc/xdg/kitty/kitty.conf` | system-wide kitty configuration: the Nerd Font, the Nord colours, the `icat` kitten |
| `etc/xdg/mimeapps.list` | which application opens which file type |
| `etc/xdg/umbriel/config.toml` | system-wide Umbriel configuration: starts Noctalia, appearance, `kitty` on `Mod+Return` |
| `etc/xdg/xdg-terminals.list` | kitty, for applications that ask `xdg-terminal-exec` for a terminal |
| `etc/zsh/moonos.zsh` | the starship prompt and the type-ahead completion, for every account |
| `usr/lib/environment.d/90-micro-editor.conf` | sets `EDITOR`/`VISUAL`/`GIT_EDITOR` to `micro` for systemd services and user sessions |
| `usr/lib/environment.d/95-terminal.conf` | sets `TERMINAL=kitty` and names the system Flatpak exports for systemd services and user sessions |
| `usr/lib/sysusers.d/noctalia-greeter.conf` | creates the `greeter` account the Noctalia greeter runs as |
| `usr/lib/tmpfiles.d/noctalia-greeter.conf` | creates `/var/lib/noctalia-greeter`, owned by `greeter` |
| `usr/libexec/moonos/enroll-akmods-key` | stages the MOK enrolment; also runnable by hand |
| `usr/libexec/moonos/select-wifi-backend` | picks `iwd` or `wpa_supplicant` based on the wireless hardware |
| `usr/share/applications/moonos-micro.desktop` | micro, in a kitty window; neither micro nor yazi ships a desktop file |
| `usr/share/applications/moonos-yazi.desktop` | yazi, in a kitty window; also the handler for folders |
| `usr/share/moonos/starship.toml` | the prompt theme; used unless the account has a `~/.config/starship.toml` |

The `environment.d` file is the important one — it is what covers a terminal
opened from the graphical session, where `/etc/profile.d` is never sourced.

### Why the yazi configuration is in `skel`

yazi reads its configuration from `$YAZI_CONFIG_HOME` or `~/.config/yazi`,
and from nowhere else: there is no system-wide path and no include
mechanism. Pointing `YAZI_CONFIG_HOME` at a directory in `/usr` would break
plugin installation, because `/usr` is read-only on an ostree system.

`/etc/skel` is the same channel the Noctalia shell uses for its defaults, and
it has the same limitation: it is copied when an account is created, so an
account that already exists has to take the configuration by hand:

```bash
cp -r /etc/skel/.config/yazi ~/.config/
```

### Why the greeter account is in `sysusers.d`

On ostree systems a user created with `useradd` from a `%post` scriptlet only
ends up in the writable `/etc` overlay and disappears on the next deployment.
`systemd-sysusers` recreates the account from `/usr` on every boot, which is
why the greeter account is declared that way.

## `files/dnf/` — repository definitions

`.repo` files placed here can be added to the image with the `dnf` module:

```yaml
modules:
  - type: dnf
    repos:
      files:
        add:
          - terra-%OS_VERSION%.repo
          - tailscale.repo
          - yazi.repo
      keys:
        - https://repos.fyralabs.com/terra%OS_VERSION%/key.asc
        - https://pkgs.tailscale.com/stable/fedora/repo.gpg
        - https://download.copr.fedorainfracloud.org/results/lihaohong/yazi/pubkey.gpg
```

The `dnf` module substitutes `%OS_VERSION%` with the `VERSION_ID` field of
`/usr/lib/os-release` before looking the file up, so the file name has to
carry the Fedora release. The module removes any repository it added once
the packages are installed.

`tailscale.repo` is a copy of Tailscale's own repository file with
`skip_if_unavailable=True` added, so that Tailscale's servers being
unreachable falls back to Fedora's copy of the package instead of failing
the build.

`yazi.repo` is the unofficial COPR that the yazi documentation points at.
It carries `$releasever` in its base URL, so it follows the Fedora release
of the base image without the file having to be renamed, and it has no
`skip_if_unavailable`: Fedora has no yazi to fall back to, so an unreachable
COPR has to stop the build rather than quietly produce an image without a
file manager.

## `files/systemd/` — systemd units

The [`systemd` module](https://blue-build.org/reference/modules/systemd/) copies
`files/systemd/system/` to `/usr/lib/systemd/system/` and
`files/systemd/user/` to `/usr/lib/systemd/user/`, then enables the units
listed under `system.enabled` / `user.enabled`.

| Unit | Purpose |
|---|---|
| `moonos-akmods-key.service` | enrols the kernel module signing key in the MOK on first boot |
| `moonos-greeter-setup.service` | creates the Noctalia greeter's state before greetd starts |
| `moonos-wifi-backend.service` | writes the NetworkManager Wi-Fi backend config |

## `files/scripts/` — run at build time

Shell scripts placed here are run by the
[`script` module](https://blue-build.org/reference/modules/script/).

```
files/
└── scripts/
    └── setup.sh
```

Enable it in `recipes/recipe.yml`:

```yaml
modules:
  - type: script
    scripts:
      - setup.sh
```

Scripts must end in `.sh`, start with a shebang, and set `set -euo pipefail`
immediately after it so that a failure fails the build.

For one-liners, the same module takes `snippets:`, which each run in their
own `/bin/sh` subshell with `set -eu`:

```yaml
modules:
  - type: script
    snippets:
      - ln -sf /usr/bin/micro /usr/bin/nano
```

The `files` module runs before the `script` module in the recipe, so a script
can `chmod` something the `files` module dropped in.
