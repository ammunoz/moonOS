#!/usr/bin/env bash
#
# Install the prebuilt kernel modules from Universal Blue's akmods bundle.
#
# BlueBuild stages that bundle at /tmp/rpms for every module of type
# "akmods" (see template/templates/modules/modules.j2 in blue-build/cli).
# The bundle holds modules prebuilt for the exact kernel of the base image,
# so neither a compiler nor kernel-devel ever ends up in the image.
#
# This module replaces the built-in akmods script, which installs through
# rpm-ostree and detours via RPM Fusion. Here dnf5 does the work.
#
# The bundle tag (akmods:main-<fedora version>) is derived by BlueBuild from
# the base image, so it always matches the kernel we are building against.

set -euo pipefail

BUNDLE="/tmp/rpms"

# The kernel modules themselves.
KMODS=(
	"${BUNDLE}"/kmods/kmod-xone-*.rpm
	"${BUNDLE}"/kmods/kmod-xpadneo-*.rpm
	"${BUNDLE}"/kmods/kmod-v4l2loopback-*.rpm
	"${BUNDLE}"/kmods/kmod-openrazer-*.rpm
	"${BUNDLE}"/kmods/kmod-wl-*.rpm
)

# Their userspace: modprobe and udev rules, the v4l2loopback control tool,
# the Broadcom wl configuration and so on.
COMMON=(
	"${BUNDLE}"/common/xone-kmod-common-*.rpm
	"${BUNDLE}"/common/xpadneo-kmod-common-*.rpm
	"${BUNDLE}"/common/v4l2loopback-*.rpm
	"${BUNDLE}"/common/openrazer-*.rpm
	"${BUNDLE}"/common/broadcom-wl-*.rpm
)

# The certificate the modules were signed with. It lives in the addons
# package, which also drops three repository files into /etc/yum.repos.d
# that we do not want in the image, so take the file out of the package
# instead of installing the package.
ADDONS=("${BUNDLE}"/ublue-os/ublue-os-akmods-addons-*.rpm)
CERT_PATH="./etc/pki/akmods/certs/akmods-ublue.der"

for rpm in "${KMODS[@]}" "${COMMON[@]}" "${ADDONS[@]}"; do
	if [[ ! -f "${rpm}" ]]; then
		echo "ERROR: ${rpm} is not in the akmods bundle" >&2
		exit 1
	fi
done

# The modules are built against exactly one kernel. That kernel is named in
# the "kernel-uname-r" requirement of the module packages, which kernel-core
# provides. If the base image has moved on to a newer kernel than the bundle
# was built for, the install cannot succeed, so fail the build instead of
# shipping an image that is missing the modules.
image_kernel=""
if rpm -q kernel-core >/dev/null 2>&1; then
	image_kernel="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | tail -1)"
elif rpm -q kernel >/dev/null 2>&1; then
	image_kernel="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | tail -1)"
fi
bundle_kernel="$(rpm -qp --requires "${KMODS[0]}" 2>/dev/null | grep -oE 'kernel-uname-r = .*' | head -1 | cut -d' ' -f3)"

if [[ -z "${image_kernel}" || -z "${bundle_kernel}" ]]; then
	echo "ERROR: could not determine the kernel versions (image: '${image_kernel}', bundle: '${bundle_kernel}')" >&2
	exit 1
fi

if [[ "${image_kernel}" != "${bundle_kernel}" ]]; then
	echo "ERROR: the base image kernel ${image_kernel} does not match the akmods" >&2
	echo "       bundle kernel ${bundle_kernel}. Universal Blue has not rebuilt" >&2
	echo "       the bundle for this kernel yet. Refusing to build an image" >&2
	echo "       that is missing the kernel modules." >&2
	exit 1
fi

echo "Installing kernel modules for ${image_kernel}:"
printf '  %s\n' "${KMODS[@]}" "${COMMON[@]}"

dnf5 -y install "${KMODS[@]}" "${COMMON[@]}"

echo "Installing the akmods signing certificate"
if ! command -v cpio >/dev/null 2>&1; then
	echo "ERROR: cpio is not available, cannot extract ${CERT_PATH}" >&2
	exit 1
fi
cd /
rpm2cpio "${ADDONS[0]}" | cpio -idm --quiet "${CERT_PATH}" || true
if [[ ! -f "/etc/pki/akmods/certs/akmods-ublue.der" ]]; then
	echo "ERROR: the akmods signing certificate was not extracted" >&2
	exit 1
fi

exit 0
