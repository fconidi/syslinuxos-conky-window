#!/bin/bash
# Build the transitional package conky-window (empty, depends on
# syslinuxos-conky-window) so that "apt upgrade" migrates existing installs
# after the rename.
#
# Output: conky-window_<VERSION>_all.deb in this directory.

set -euo pipefail

PKG_VERSION="0.2.0"
PKG_NAME="conky-window"
NEW_NAME="syslinuxos-conky-window"

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
STAGING="${WORKDIR}/staging-transitional"
OUTPUT_DEB="${WORKDIR}/${PKG_NAME}_${PKG_VERSION}_all.deb"

rm -rf "$STAGING"
mkdir -p "$STAGING/DEBIAN"

cat > "$STAGING/DEBIAN/control" <<EOT
Package: $PKG_NAME
Version: $PKG_VERSION
Section: oldlibs
Priority: optional
Architecture: all
Depends: $NEW_NAME (>= $PKG_VERSION)
Maintainer: Franco Conidi (edmond) <fconidi@gmail.com>
Homepage: https://syslinuxos.com
Installed-Size: 1
Description: transitional package, conky-window is now syslinuxos-conky-window
 This empty package only pulls in syslinuxos-conky-window and can be safely
 removed once the upgrade is complete.
EOT

rm -f "$OUTPUT_DEB"
fakeroot dpkg-deb --build "$STAGING" "$OUTPUT_DEB"
rm -rf "$STAGING"
echo "Build OK: $OUTPUT_DEB"
