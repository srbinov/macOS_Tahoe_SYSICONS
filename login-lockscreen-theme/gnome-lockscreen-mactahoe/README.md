# GNOME lock screen — MacTahoe-Dark-orange theme

System-wide GNOME Shell theme, set as the *default* (not tied to one
user account) via dconf. This is what drives the look of the GNOME
lock screen (Super+L) as well as the overview/top bar, through the
standard "User Themes" extension mechanism.

## Contents
- `MacTahoe-Dark-orange/` — the shell theme (GTK + gnome-shell CSS/assets)
- `01-mactahoe-theme` — dconf system-default snippet: enables the
  `user-theme` extension and points it at this theme
- `install.sh` — copies the theme system-wide and applies the dconf default

## Install (inside the VM, as root)
```
sudo ./install.sh
```
Takes effect on next login/lock for any user that hasn't set their own
shell theme preference (i.e. it's a default, not a forced override).

## Manual steps (if the script doesn't fit your image)
1. `apt install gnome-shell-extension-user-theme` (if not already present)
2. `cp -r MacTahoe-Dark-orange /usr/share/themes/`
3. `cp 01-mactahoe-theme /etc/dconf/db/local.d/`
4. `dconf update`

## Notes
- No wallpaper, username, or avatar is included — this is purely the
  shell/lock-screen chrome (colors, shapes, panel/dialog styling).
- Deliberately scoped to just the theme + the extension that loads it;
  it does not touch any other GNOME Shell extensions.
