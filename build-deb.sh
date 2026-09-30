#!/bin/bash
# Build syslinuxos-conky-window (renamed from conky-window in 0.2.0).
#
# Output: syslinuxos-conky-window_<VERSION>_all.deb in this directory.
# No sudo: fakeroot handles root permissions.

set -euo pipefail

PKG_VERSION="0.2.2"
PKG_NAME="syslinuxos-conky-window"
ARCH="all"

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
FILES_DIR="${WORKDIR}/files"
STAGING="${WORKDIR}/staging"
OUTPUT_DEB="${WORKDIR}/${PKG_NAME}_${PKG_VERSION}_${ARCH}.deb"

echo "==> Workspace: $WORKDIR"
echo "==> Target: $OUTPUT_DEB"

# --- 1. Clean staging and copy files/ ---
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -a "$FILES_DIR"/* "$STAGING/"

# --- 1b. Permissions ---
chmod 755 "$STAGING/opt/scripts/conky-window-start.sh" \
          "$STAGING/opt/scripts/conky-window-stop.sh" \
          "$STAGING/opt/scripts/conky-hardware.sh" \
          "$STAGING/opt/scripts/conky-net.sh" \
          "$STAGING/opt/scripts/conky-syslinuxos.sh"
chmod 644 "$STAGING/etc/conky/conky-window.conf"
chmod 644 "$STAGING/usr/share/applications/"*.desktop "$STAGING/usr/share/pixmaps/"*.png
chmod 644 "$STAGING/usr/share/doc/$PKG_NAME/"*

# --- 2. DEBIAN/control ---
mkdir -p "$STAGING/DEBIAN"
INSTALLED_SIZE=$(du -sk "$STAGING" --exclude=DEBIAN | cut -f1)

cat > "$STAGING/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Section: x11
Priority: optional
Architecture: $ARCH
Depends: conky-all
Recommends: lsb-release, curl, lm-sensors, x11-utils, x11-xserver-utils
Replaces: conky-window (<< 0.2.0)
Breaks: conky-window (<< 0.2.0)
Maintainer: Franco Conidi (edmond) <fconidi@gmail.com>
Homepage: https://syslinuxos.com
Installed-Size: $INSTALLED_SIZE
Description: Standard Conky window theme for SysLinuxOS
 System monitor panel (CPU per-core, top processes, memory, filesystem,
 network) integrated into the System > Monitor menu of SysLinuxOS.
 .
 Auto-scales font sizes, widths and bar dimensions to the screen resolution
 at startup (reference 1920x1080, override with CONKY_WINDOW_SCALE=<n>).
 CPU bars are generated dynamically for any number of logical processors.
 Configuration template: /etc/conky/conky-window.conf.
EOF

# conffiles: dpkg preserves user edits across upgrades
echo "/etc/conky/conky-window.conf" > "$STAGING/DEBIAN/conffiles"

# --- 3. postinst ---
cat > "$STAGING/DEBIAN/postinst" <<'POSTINST'
#!/bin/bash
set -e

case "$1" in
    configure)
        # Divert conky.desktop from conky-all to avoid duplicate menu entry.
        # Our conky-window-start.desktop replaces it.
        # Migration from the old package name: take over its diversion.
        if dpkg-divert --list /usr/share/applications/conky.desktop 2>/dev/null | grep -q ' by conky-window$'; then
            dpkg-divert --package conky-window \
                --rename \
                --remove /usr/share/applications/conky.desktop \
                2>/dev/null || true
        fi
        if ! dpkg-divert --list /usr/share/applications/conky.desktop 2>/dev/null | grep -q ' by syslinuxos-conky-window$'; then
            dpkg-divert --package syslinuxos-conky-window \
                --rename \
                --divert /usr/share/applications/conky.desktop.distrib \
                /usr/share/applications/conky.desktop \
                2>/dev/null || true
        fi
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
        fi
        echo
        echo "syslinuxos-conky-window: installation complete."
        echo "  - Start: Menu > System > Monitor > Conky-window-start"
        echo "  - Stop:  Menu > System > Monitor > Conky-window-stop"
        ;;
    abort-upgrade|abort-remove|abort-deconfigure)
        ;;
    *)
        echo "postinst called with unknown argument \`$1'" >&2
        exit 1
        ;;
esac

exit 0
POSTINST

# --- 4. prerm ---
cat > "$STAGING/DEBIAN/prerm" <<'PRERM'
#!/bin/sh
set -e

case "$1" in
    remove|deconfigure)
        for PID in $(pgrep -x conky 2>/dev/null); do
            cmdline=$(tr '\0' ' ' < /proc/"$PID"/cmdline 2>/dev/null)
            if ! echo "$cmdline" | grep -q "conkyrc"; then
                kill "$PID" 2>/dev/null || true
            fi
        done
        ;;
    upgrade|failed-upgrade)
        ;;
    *)
        echo "prerm called with unknown argument \`$1'" >&2
        exit 1
        ;;
esac

exit 0
PRERM

# --- 5. postrm ---
cat > "$STAGING/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e

case "$1" in
    remove|purge)
        # Remove divert of conky.desktop (restore conky-all's file).
        if dpkg-divert --list /usr/share/applications/conky.desktop 2>/dev/null | grep -q ' by syslinuxos-conky-window$'; then
            dpkg-divert --package syslinuxos-conky-window \
                --rename \
                --remove /usr/share/applications/conky.desktop \
                2>/dev/null || true
        fi
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
        fi
        ;;
    upgrade|failed-upgrade|abort-install|abort-upgrade|disappear)
        ;;
    *)
        echo "postrm called with unknown argument \`$1'" >&2
        exit 1
        ;;
esac

exit 0
POSTRM

chmod 755 "$STAGING/DEBIAN/postinst" "$STAGING/DEBIAN/prerm" "$STAGING/DEBIAN/postrm"

# --- 6. md5sums ---
echo "==> Generating md5sums"
(cd "$STAGING" && find . -type f -not -path './DEBIAN/*' -printf '%P\n' | sort | xargs -d '\n' md5sum > DEBIAN/md5sums)

# --- 7. Build .deb ---
echo "==> Building .deb (fakeroot)"
rm -f "$OUTPUT_DEB"
fakeroot dpkg-deb --build "$STAGING" "$OUTPUT_DEB"

# --- 8. Verify ---
echo
echo "==> .deb produced:"
ls -la "$OUTPUT_DEB"
echo
echo "==> Metadata:"
dpkg-deb -I "$OUTPUT_DEB" | grep -E "^ (Package|Version|Architecture|Depends|Maintainer)"
echo
echo "==> Contents:"
dpkg-deb -c "$OUTPUT_DEB" | awk '{print $1, $6}'

echo
echo "Build OK: $OUTPUT_DEB"
echo
echo "To install/test:"
echo "  sudo apt install $OUTPUT_DEB"
