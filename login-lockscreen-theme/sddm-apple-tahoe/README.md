# SDDM login screen — Apple.Tahoe theme

System-wide SDDM greeter theme. This is the screen shown before *any*
session starts (GNOME or KDE), so it becomes the distro's default login
screen for every user/account, not just one.

## Contents
- `Apple.Tahoe/` — the QML greeter theme itself
- `Apple-cursors/` — cursor theme the greeter references (`CursorTheme=Apple-cursors`)
- `sf-pro-display/` — the two font files the greeter chrome uses (`Font=SF Pro Display`)
- `90-apple-tahoe.conf` — the sddm.conf.d snippet that selects the theme
- `install.sh` — copies everything into place and installs the config

## Install (inside the VM, as root)
```
sudo ./install.sh
sudo systemctl restart sddm   # or just reboot
```

## Manual steps (if the script doesn't fit your image)
1. `cp -r Apple.Tahoe /usr/share/sddm/themes/`
2. `cp -r Apple-cursors /usr/share/icons/`
3. `cp sf-pro-display/*.otf /usr/share/fonts/apple-tahoe/ && fc-cache -f`
4. `cp 90-apple-tahoe.conf /etc/sddm.conf.d/`
5. Restart `sddm.service` or reboot

## Notes
- Requires `sddm` to be the display manager (it is on this build).
- No user-specific data is baked in here (no wallpaper/username/avatar) —
  purely the greeter chrome/background/cursor/font that make up the look.
