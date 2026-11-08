#!/bin/bash
# Build patched grub2 packages for the Debian release of the running container.
# Usage: build.sh <outdir>   (run as root inside debian:<release>)
set -euo pipefail

OUT=$(realpath -m "$1")
REPO=$(cd "$(dirname "$0")/.." && pwd)
REV=$(cat "$REPO/REVISION")
. /etc/os-release
REL=$VERSION_CODENAME
export DEBIAN_FRONTEND=noninteractive

# Enable deb-src for the release, -updates and -security
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
apt-get update
apt-get install -y --no-install-recommends dpkg-dev quilt fakeroot ca-certificates

DEBVER=$(apt-cache showsrc grub2 | sed -n 's/^Version: //p' | sort -V | tail -1)
NEWVER="${DEBVER}+urbackup${REV}"
echo "Debian grub2 $DEBVER -> $NEWVER"

WORK=$(mktemp -d)
cd "$WORK"
apt-get source "grub2=$DEBVER"
cd grub2-*/

# Add our patch on top of the Debian patch series
cp "$REPO/patches/urbackup-grub.patch" debian/patches/urbackup-grub.patch
echo urbackup-grub.patch >> debian/patches/series
QUILT_PATCHES=debian/patches quilt push -a

{
  cat <<CL
grub2 ($NEWVER) $REL; urgency=medium

  * Apply urbackup-grub.patch: let grub-probe/grub-install see through
    UrBackup device-mapper snapshot devices to the real root device.

 -- UrBackup GRUB build <github-actions@users.noreply.github.com>  $(date -R)

CL
  cat debian/changelog
} > debian/changelog.new
mv debian/changelog.new debian/changelog

apt-get build-dep -y ./
DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -us -uc -sa

mkdir -p "$OUT/pool/main/g/grub2"
cd "$WORK"
for f in *.deb *.dsc *.tar.* ; do
  case "$f" in
    *-dbg_*|*-dbgsym_*) continue ;;   # huge, not needed
  esac
  cp "$f" "$OUT/pool/main/g/grub2/"
done

# Repackage Debian's signed EFI binaries so their exact-version dependency
# on grub-common matches our rebuilt packages. The signed images themselves
# are untouched (the patch only changes userland tools).
ARCH=$(dpkg --print-architecture)
case "$ARCH" in
  amd64) SIGNED=grub-efi-amd64-signed ;;
  arm64) SIGNED=grub-efi-arm64-signed ;;
  *) SIGNED= ;;
esac
if [ -n "$SIGNED" ]; then
  mkdir "$WORK/signed" && cd "$WORK/signed"
  apt-get download "$SIGNED"
  deb=$(ls ./*.deb)
  dpkg-deb -R "$deb" pkg
  built_using=$(sed -n 's/^Built-Using: //p' pkg/DEBIAN/control)
  if [ "$built_using" != "grub2 (= $DEBVER)" ]; then
    echo "ERROR: $SIGNED is built from '$built_using', expected grub2 $DEBVER" >&2
    exit 1
  fi
  sver=$(sed -n 's/^Version: //p' pkg/DEBIAN/control)
  sed -i \
    -e "s/^Version: .*/Version: ${sver}+urbackup${REV}/" \
    -e "/^Depends:/s/grub-common ([<>=]* *[^)]*)/grub-common (= $NEWVER)/" \
    pkg/DEBIAN/control
  cat pkg/DEBIAN/control
  dpkg-deb --root-owner-group -b pkg "$OUT/pool/main/g/grub2/${SIGNED}_${sver}+urbackup${REV}_${ARCH}.deb"
fi

echo "$NEWVER" > "$OUT/VERSION"
ls -la "$OUT/pool/main/g/grub2"
