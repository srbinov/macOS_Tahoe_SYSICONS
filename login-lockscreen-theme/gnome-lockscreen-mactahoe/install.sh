#!/usr/bin/env bash
# Installs the MacTahoe-Dark-orange GNOME Shell theme as the system default
# (drives the GNOME lock screen / overview look for every user).
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo ./install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! dpkg -s gnome-shell-extension-user-theme >/dev/null 2>&1; then
  echo "==> gnome-shell-extension-user-theme not found, installing..."
  apt-get update -qq && apt-get install -y gnome-shell-extension-user-theme
fi

echo "==> Installing MacTahoe-Dark-orange to /usr/share/themes/"
rm -rf /usr/share/themes/MacTahoe-Dark-orange
cp -r "$DIR/MacTahoe-Dark-orange" /usr/share/themes/MacTahoe-Dark-orange

echo "==> Setting it as the default shell theme via dconf"
mkdir -p /etc/dconf/db/local.d
cp "$DIR/01-mactahoe-theme" /etc/dconf/db/local.d/01-mactahoe-theme
dconf update

echo "==> Done. Any user without their own override (fresh accounts included)"
echo "    will get MacTahoe-Dark-orange as the shell/lock-screen theme."
