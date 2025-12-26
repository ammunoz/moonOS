#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/medusalix/xone.git"
WORKDIR="$(mktemp -d)"

cleanup() {
  echo "Cleaning up ${WORKDIR}.."
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

# IMPORTANT:
# - This script runs during the image build, inside a container.
# - `uname -r` would report the GitHub runner kernel, not the kernel shipped in the image.
#   So we derive the target kernel version from the image's /usr/lib/modules instead.
if [[ -d /usr/lib/modules ]]; then
  KVER="$(ls -1 /usr/lib/modules | sort -V | tail -n1)"
else
  echo "ERROR: /usr/lib/modules not found; cannot determine target kernel version" >&2
  exit 1
fi

dnf -y install \
  cabextract \
  dkms \
  kmod \
  git \
  "kernel-devel-${KVER}" \
  "kernel-headers"

echo "Cloning '${REPO_URL}' into '${WORKDIR}'.."
git clone --depth=1 "${REPO_URL}" "${WORKDIR}"

echo "Changing directory into '${WORKDIR}'.."
pushd "${WORKDIR}"

echo "Running install.sh.."
chmod +x ./install.sh
if ! sudo ./install.sh; then
  echo "Error: install.sh returned with a non-zero exit code."
  exit 1
fi

echo "Running firmware.sh.."
chmod +x ./install/firmware.sh
if ! sudo ./install/firmware.sh --skip-disclaimer; then
  echo "Error: firmware.sh returned with a non-zero exit code."
  exit 1
fi

echo "Done!"

popd

