# `files/`

Drop-in directories that BlueBuild modules read at build time.

```
files/
├── dnf/
│   └── terra-44.repo        the Terra repository definition
├── system/                  copied into the image root
│   ├── etc/
│   │   ├── profile.d/
│   │   │   └── micro.sh
│   │   └── xdg/
│   │       └── umbriel/
│   │           └── config.toml
│   └── usr/
│       ├── lib/
│       │   ├── environment.d/
│       │   │   └── 90-micro-editor.conf
│       │   ├── sysusers.d/
│       │   │   └── noctalia-greeter.conf
│       │   └── tmpfiles.d/
│       │       └── noctalia-greeter.conf
│       └── libexec/
│           └── moonos/
│               └── select-wifi-backend
└── systemd/
    └── system/
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
| `etc/xdg/umbriel/config.toml` | system-wide Umbriel configuration: starts Noctalia, appearance, `foot` on `Mod+Return` |
| `usr/lib/environment.d/90-micro-editor.conf` | sets `EDITOR`/`VISUAL`/`GIT_EDITOR` to `micro` for systemd services and user sessions |
| `usr/lib/sysusers.d/noctalia-greeter.conf` | creates the `greeter` account the Noctalia greeter runs as |
| `usr/lib/tmpfiles.d/noctalia-greeter.conf` | creates `/var/lib/noctalia-greeter`, owned by `greeter` |
| `usr/libexec/moonos/select-wifi-backend` | picks `iwd` or `wpa_supplicant` based on the wireless hardware |

The `environment.d` file is the important one — it is what covers a terminal
opened from the graphical session, where `/etc/profile.d` is never sourced.

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
      keys:
        - https://repos.fyralabs.com/terra%OS_VERSION%/key.asc
```

The `dnf` module substitutes `%OS_VERSION%` with the `VERSION_ID` field of
`/usr/lib/os-release` before looking the file up, so the file name has to
carry the Fedora release. The module removes any repository it added once
the packages are installed.

## `files/systemd/` — systemd units

The [`systemd` module](https://blue-build.org/reference/modules/systemd/) copies
`files/systemd/system/` to `/usr/lib/systemd/system/` and
`files/systemd/user/` to `/usr/lib/systemd/user/`, then enables the units
listed under `system.enabled` / `user.enabled`.

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
