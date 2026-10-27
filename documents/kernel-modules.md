# Kernel modules

moonOS ships the kernel modules that desktop users actually need — gamepad
drivers, virtual cameras, Razer device support — but does not compile them.

## Why they are prebuilt

The modules are prebuilt by Universal Blue for the exact kernel of the base
image, so the image needs neither a compiler nor `kernel-devel`. The price is
that the modules only work on the kernel they were built for.

| Module | For |
|---|---|
| `xone` | Xbox One controllers over USB |
| `xpadneo` | Xbox One controllers over Bluetooth |
| `v4l2loopback` | virtual cameras |
| `openrazer` | Razer devices (with the daemon from Terra) |
| `wl` | Broadcom wireless cards |

## How they get installed

BlueBuild stages Universal Blue's bundle at `/tmp/rpms` automatically for any
module of type `akmods`. The recipe uses that module type with
`source: local`, so [`modules/akmods/akmods.sh`](../modules/akmods/akmods.sh)
does the install with `dnf5` instead of the built-in script — the built-in one
installs through `rpm-ostree` and detours via RPM Fusion.

The script picks the packages out of the bundle:

| Bundle path | Contents |
|---|---|
| `kmods/kmod-*.rpm` | the kernel modules themselves |
| `common/*.rpm` | their userspace: modprobe and udev rules, the v4l2loopback control tool, the Broadcom `wl` configuration |
| `ublue-os/ublue-os-akmods-addons-*.rpm` | the signing certificate, plus three repository files that are not wanted in the image |

The addons package is not installed. The certificate is taken out of it
instead, with `rpm2cpio` and `cpio`, and lands at
`/etc/pki/akmods/certs/akmods-ublue.der`.

## Why not the built-in module

BlueBuild ships a built-in `akmods` module, documented at
[blue-build.org/reference/modules/akmods](https://blue-build.org/reference/modules/akmods/).
The recipe's `type: akmods` names that module, but `source: local` replaces
its script with [`modules/akmods/akmods.sh`](../modules/akmods/akmods.sh),
so the documented options do not apply:

| Documented option | Here |
|---|---|
| `install:` — the list of modules to install | not used; the script globs the bundle itself (`kmod-xone-*.rpm` and so on) |
| `nvidia-driver:` — `nvidia` or `nvidia-open` | not used; moonOS ships no NVIDIA driver |
| `base:` — the kernel flavour | `main`; this is what picks the bundle that gets staged |

The differences that matter are in the install itself:

- The built-in script installs through `rpm-ostree` and temporarily installs
  **RPM Fusion**, which the `wl` and `v4l2loopback` akmods need. moonOS
  takes the packages out of the bundle and installs them with `dnf5`, so no
  RPM Fusion repository ever enters the image.
- The built-in script resolves the userspace packages — the "common" ones
  with the modprobe and udev rules — from the `ublue-os/akmods` COPR. Here
  they are installed from the bundle. That is what the upstream
  documentation's *"some akmods are not installing due to lack of some
  additional akmod package"* problem is about: with the built-in script the
  image needs a second repository in the `rpm-ostree` module. It does not
  apply to moonOS.
- The built-in script does not take the signing certificate out of the
  addons package, which the [Secure Boot](#secure-boot) section needs.
- The built-in script has no kernel-match check. Upstream lists the
  resulting build failure as a known issue: the transaction dies with a
  dependency solving error when the bundle is older than the base image's
  kernel. moonOS stops earlier, with a clear message — see
  [the kernel-match check](#the-kernel-match-check).

### The recipe entry is a custom module

`bluebuild validate`, which CI runs on the recipe, checks each module entry
against the published JSON schema. An entry has to match either a built-in
module schema or the generic custom module schema, and this one matches the
**custom** one:

- the built-in `akmods` schema requires `install:` and allows no other key,
  `source:` included
- the custom module schema requires `type:` and `source:`, and allows
  anything else

So the entry

```yaml
- type: akmods
  source: local
  base: main
```

is valid because of `source: local`, and the missing `install:` list is not
an oversight. Removing `source: local` means adding `install:` as well,
and that switches the build over to the built-in script with all the
differences listed above.

## Why the bundle goes in first

The `akmods` module runs **before** the `dnf` module in the recipe, and that
order matters.

`openrazer-daemon` depends on the `openrazer` package, which in turn needs
something to provide the virtual `openrazer-kmod`. Two packages provide it:

- `kmod-openrazer` — the prebuilt module from the bundle, which is what
  moonOS ships
- `akmod-openrazer` — the source package from Terra, whose install script
  compiles the module on the spot and refuses to run as root

Until the bundle is installed, dnf can only see the second one, pulls it in,
and the transaction dies with:

```
Building /usr/src/akmods/openrazer-kmod-3.12.4-2.fc44.src.rpm for kernel 7.2.11-200.fc44.x86_64
ERROR: Not to be used as root; start as user or 'akmodsbuild' instead.
```

Installing the prebuilt module first means dnf finds the provider it needs
among the installed packages and never pulls in the akmod package. Moving
the `akmods` module back below the `dnf` module brings that failure back.

## The kernel-match check

The bundle is built for one kernel at a time. Two guards keep the image from
being published without its modules:

**Before the build** — [`scripts/check-akmods-kernel.py`](../scripts/check-akmods-kernel.py)
reads the `ostree.linux` label of the base image and of Universal Blue's
bundle and compares the two. When they differ the build stops rather than
publishing an image whose kernel modules cannot be installed. The bundle is
rebuilt daily, so the next run picks the new one up. The check can be run by
hand at any time:

```bash
python3 scripts/check-akmods-kernel.py
```

**During the install** — `akmods.sh` compares the `kernel-uname-r`
requirement of the module RPMs — read from the first one — against the kernel
in the image and aborts if they differ.

## The staging is deprecated upstream

BlueBuild hands the bundle to the module through a mount that its own
templates mark as `TODO: Needs to be deprecated`:

```
{#- Akmods mount #}
{#- TODO: Needs to be deprecated #}
```

The built-in script and [`modules/akmods/akmods.sh`](../modules/akmods/akmods.sh)
both read the bundle from that mount, so when it goes the build fails with
`ERROR: ... is not in the akmods bundle`. The upstream issues to watch are:

- [blue-build/cli#354](https://github.com/blue-build/cli/issues/354) — akmods
  tags keyed by kernel version, which would change the `main-<version>` tag
  that [`scripts/check-akmods-kernel.py`](../scripts/check-akmods-kernel.py)
  looks for
- [blue-build/cli#882](https://github.com/blue-build/cli/issues/882) — the next
  generation build engine

Until then, nothing has to change. If the mount does go, the way out is for
the script to fetch the bundle itself — `skopeo copy` from
`ghcr.io/ublue-os/akmods:main-<version>`, the way the built-in script's
Nvidia path already does it.

## Secure Boot

The modules are signed with Universal Blue's key, which a Secure Boot system
has to trust before the kernel will load them. moonOS ships the certificate
and stages it for enrolment on first boot. The procedure the *user* follows
on their machine is in the [root README](../README.md#secure-boot).

## See also

- [image-composition.md](image-composition.md) — the rest of what goes into the image
- [building.md](building.md) — how the image gets built and published
