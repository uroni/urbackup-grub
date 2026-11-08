#!/bin/bash
# Regenerate and sign APT indexes for one release directory.
# Usage: update-repo.sh <site-dir> <release>
set -euo pipefail
cd "$1/$2"
REL=$2
for arch in amd64; do
  d=dists/$REL/main/binary-$arch
  mkdir -p "$d"
  apt-ftparchive --arch "$arch" packages pool > "$d/Packages"
  gzip -9kf "$d/Packages"; xz -kf "$d/Packages"
done
mkdir -p dists/$REL/main/source
apt-ftparchive sources pool > dists/$REL/main/source/Sources
gzip -9kf dists/$REL/main/source/Sources; xz -kf dists/$REL/main/source/Sources

cd dists/$REL
rm -f Release InRelease Release.gpg
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=UrBackup \
  -o APT::FTPArchive::Release::Label="UrBackup GRUB" \
  -o APT::FTPArchive::Release::Suite="$REL" \
  -o APT::FTPArchive::Release::Codename="$REL" \
  -o APT::FTPArchive::Release::Architectures="amd64" \
  -o APT::FTPArchive::Release::Components=main \
  -o APT::FTPArchive::Release::Description="GRUB with UrBackup snapshot patch for Debian $REL" \
  release . > ../Release.tmp
mv ../Release.tmp Release
gpg --batch --yes --clearsign -o InRelease Release
gpg --batch --yes -abs -o Release.gpg Release
