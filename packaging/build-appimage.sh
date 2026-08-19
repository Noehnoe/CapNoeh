#!/usr/bin/env bash
# Build CapNoeh.AppImage
#
# The AppImage bundles the launcher but deliberately uses the host's Python,
# GTK 3 and Wine. Bundling GTK would tie the binary to the glibc of whatever
# machine built it, which makes it *less* portable, not more — and the app
# already requires host Wine regardless.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
OUT="${1:-$ROOT/dist}"
APPDIR="$(mktemp -d)/CapNoeh.AppDir"

mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

install -m755 "$ROOT/app/capnoeh-launcher" "$APPDIR/usr/bin/capnoeh-launcher"
install -m644 "$ROOT/docs/capnoeh-256.png" \
              "$APPDIR/usr/share/icons/hicolor/256x256/apps/capnoeh.png"
install -m644 "$ROOT/docs/capnoeh-256.png" "$APPDIR/capnoeh.png"

cat > "$APPDIR/capnoeh.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=CapNoeh
GenericName=CapCut Installer & Launcher
Comment=Install and launch CapCut on Linux under Wine
Exec=capnoeh-launcher
Icon=capnoeh
Categories=AudioVideo;Video;AudioVideoEditing;
Keywords=capcut;video;editor;wine;
Terminal=false
StartupNotify=true
EOF
install -m644 "$APPDIR/capnoeh.desktop" \
              "$APPDIR/usr/share/applications/capnoeh.desktop"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="$HERE/usr/bin:$PATH"

die() {
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --error "$1"
    elif command -v zenity >/dev/null 2>&1; then
        zenity --error --width=420 --text="$1"
    fi
    echo "CapNoeh: $1" >&2
    exit 1
}

command -v python3 >/dev/null 2>&1 || die "Python 3 is required but was not found."

python3 - <<'PY' 2>/dev/null || die "CapNoeh needs GTK 3 with Python bindings.

Install one of:
  Fedora/Nobara:  sudo dnf install python3-gobject gtk3
  Debian/Ubuntu:  sudo apt install python3-gi gir1.2-gtk-3.0
  Arch:           sudo pacman -S python-gobject gtk3"
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
PY

exec python3 "$HERE/usr/bin/capnoeh-launcher" "$@"
EOF
chmod +x "$APPDIR/AppRun"

mkdir -p "$OUT"
ARCH=x86_64 appimagetool "$APPDIR" "$OUT/CapNoeh-x86_64.AppImage"
echo "built: $OUT/CapNoeh-x86_64.AppImage"
