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

## The kernel-match check

The bundle is built for one kernel at a time. Two guards keep the image from
being published without its modules:

**Before the build** — [`.forgejo/scripts/check-akmods-kernel.py`](../.forgejo/scripts/check-akmods-kernel.py)
reads the `ostree.linux` label of the base image and of Universal Blue's
bundle and compares the two. When they differ the build stops rather than
publishing an image whose kernel modules cannot be installed. The bundle is
rebuilt daily, so the next run picks the new one up. The check can be run by
hand at any time:

```bash
python3 .forgejo/scripts/check-akmods-kernel.py
```

**During the install** — `akmods.sh` compares the `kernel-uname-r`
requirement of the module RPMs — read from the first one — against the kernel
in the image and aborts if they differ.

## Secure Boot

The modules are signed with Universal Blue's key, which a Secure Boot system
has to trust before the kernel will load them. moonOS ships the certificate
and stages it for enrolment on first boot. The procedure the *user* follows
on their machine is in the [root README](../README.md#secure-boot).

## See also

- [image-composition.md](image-composition.md) — the rest of what goes into the image
- [building.md](building.md) — how the image gets built and published
