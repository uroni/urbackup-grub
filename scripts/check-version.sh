#!/bin/bash
# Print the package version that build.sh would produce for this container.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
apt-get update -qq >/dev/null
echo "$(apt-cache showsrc grub2 | sed -n 's/^Version: //p' | sort -V | tail -1)+urbackup$(cat "$REPO/REVISION")"
