# Login + lock screen theme

System-wide theming for a custom Ubuntu-based (26.04) distro built with
[penguins-eggs](https://github.com/pieroproietti/penguins-eggs). Reproduces
the Apple Tahoe-styled login screen and lock screen as OS defaults — not
tied to any single user account (no wallpaper/username/avatar baked in).

- `sddm-apple-tahoe/` — the **login screen** (SDDM greeter theme, applies
  before any session starts, shared across desktop environments)
- `gnome-lockscreen-mactahoe/` — the **GNOME lock screen** (shell theme set
  as the system default via dconf + the standard `user-theme` extension)

Each folder has its own `install.sh` (run as root inside the target
system/chroot) and `README.md` with manual fallback steps.

## Credits
- SDDM theme: [zayronxio/Sonoma-SDDMT](https://github.com/zayronxio/Sonoma-SDDMT)
  (ISC-style license, see `sddm-apple-tahoe/Apple.Tahoe/LICENSE`)
- Cursor theme: Apple-cursors (community macOS-style cursor set)
- Shell theme: MacTahoe-Dark-orange (community GNOME Shell theme)
- SF Pro Display fonts are Apple's proprietary font files, included here
  for convenience — check Apple's font license before redistributing
  further.
