#!/usr/bin/env bash
# Installs the Apple.Tahoe SDDM greeter theme as the system default.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Apple.Tahoe theme to /usr/share/sddm/themes/"
rm -rf /usr/share/sddm/themes/Apple.Tahoe
cp -r "$DIR/Apple.Tahoe" /usr/share/sddm/themes/Apple.Tahoe

echo "==> Installing Apple-cursors to /usr/share/icons/"
rm -rf /usr/share/icons/Apple-cursors
cp -r "$DIR/Apple-cursors" /usr/share/icons/Apple-cursors

echo "==> Installing SF Pro Display fonts to /usr/share/fonts/"
mkdir -p /usr/share/fonts/apple-tahoe
# Case-insensitive glob -- the bundled files ship as *.OTF, not *.otf.
shopt -s nocaseglob
cp "$DIR"/sf-pro-display/*.otf /usr/share/fonts/apple-tahoe/
shopt -u nocaseglob
fc-cache -f >/dev/null

echo "==> Setting Apple.Tahoe as the default SDDM theme"
mkdir -p /etc/sddm.conf.d
cp "$DIR/90-apple-tahoe.conf" /etc/sddm.conf.d/90-apple-tahoe.conf

echo "==> Done. Restart sddm to preview: sudo systemctl restart sddm"
echo "    (or just leave it — it applies automatically on next boot)"
