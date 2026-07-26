# Fedora 44 + Niri + Noctalia-shell

Automated setup script for a clean, minimal Fedora 44 workstation built around [`niri`](https://github.com/YaLTeR/niri) and [`noctalia-shell`](https://github.com/noctalia-dev/noctalia-shell), with automatic GPU driver setup (NVIDIA / Intel / AMD), sensible defaults, optional applications, and preconfigured keybinds.

> [!NOTE]
> - Run the script as a regular user (not root), `sudo` is invoked internally when needed.
> - Most pre-installed GNOME apps are removed to keep the system minimal, including `GNOME Software`. Manage Flatpaks with `Bazaar`, installed by default.

---

## Contents

- [Installation](#installation)
- [Graphics drivers](#graphics-drivers)
- [Logitech K380 keyboard](#logitech-k380-keyboard)
- [Steam H.264 codec support](#steam-h264-codec-support)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Installed by default](#installed-by-default)
- [Optional](#optional)

---

# Installation

## 1. Create a bootable USB drive

Use `Ventoy` or `Fedora Media Writer` with the [**Fedora Everything 44**](https://fedoraproject.org/misc/#everything) ISO.

During installation:

- Select `Fedora Workstation`
- Enable `C Development Tools and Libraries` and `Development Tools`

## 2. Clone and run the setup script

```bash
git clone https://github.com/lucasobx/fedora-niri.git ~/fedora-niri
cd ~/fedora-niri
chmod +x fedora-niri.sh && ./fedora-niri.sh
```

When it finishes, reboot and select the `niri` session at GDM before logging in.

Optionally remove the pre-installed GNOME terminal:

```bash
sudo dnf remove ptyxis
```

---

# Graphics drivers

The script detects your GPU automatically and sets up the matching stack:

- **NVIDIA** - proprietary drivers from RPM Fusion (you confirm the branch: *current* for Turing / RTX 20 and newer, or *legacy 580xx* for Maxwell / Pascal), DRM modeset for Wayland, and the niri VRAM-usage fix.
- **Intel** - `intel-media-driver` with `LIBVA_DRIVER_NAME=iHD` for VA-API.
- **AMD** - in-kernel `amdgpu` + Mesa, with the VA/VDPAU drivers swapped to the RPM Fusion `freeworld` builds for full H.264 / H.265 hardware decoding.

> [!NOTE]
> If an NVIDIA GPU is detected, the drivers become active after rebooting (check with `nvidia-smi`). Make sure **Secure Boot is disabled**.

---

# Logitech K380 keyboard

If you answer yes during setup, the script installs [`k380-function-keys-conf`](https://github.com/jergusg/k380-function-keys-conf) so the top row acts as standard **F keys**.

---

# Steam H.264 codec support

If you installed Steam, enable H.264 codec support by closing Steam completely and running:

```bash
steam steam://unlockh264/
```

Steam relaunches automatically. When it finishes, close and reopen it normally.

---

# Keyboard shortcuts

All shortcuts use the **Super** (`Mod`) key. Press `Mod` + `Shift` + `/` to show the in-session cheat sheet.

| Action | Shortcut |
|--------|----------|
| Terminal (kitty) | `Mod` + `Return` |
| Browser (Zen) | `Mod` + `B` |
| Files (Nautilus) | `Mod` + `N` |
| Launcher | `Mod` + `Space` |
| Overview | `Mod` + `O` |
| Screenshot (region / screen / window) | `Print` / `Ctrl` + `Print` / `Alt` + `Print` |
| Focus column left/right | `Mod` + `←` / `→` |
| Focus window down/up | `Mod` + `↓` / `↑` |
| Move column left/right | `Mod` + `Ctrl` + `←` / `→` |
| Switch workspace | `Mod` + `PgUp` / `PgDn` (or `Mod` + `U` / `I`) |
| Move column to workspace | `Mod` + `Ctrl` + `PgUp` / `PgDn` |
| Maximize column | `Mod` + `F` |
| Close window | `Mod` + `Q` |
| Quit niri | `Mod` + `Shift` + `E` |

A full list is in `~/.config/niri/config.kdl`.

---

# Installed by default

## Desktop environment

- Niri
- Noctalia-shell
- Numix icon themes

## Graphics

- Auto-detected NVIDIA / Intel / AMD driver stack)

## Applications
- Libre Menu Editor
- Zen Browser
- Localsend
- Monique
- Bazaar
- Kitty

### CLI Tools
- `mise`, `pipx`, `zoxide`, `fastfetch`, `fd-find`, `wf-recorder`, `slurp`

---

# Optional

## Applications
- OBS Studio
- Gear Lever
- Resources
- qBittorrent
- Telegram
- Spotify
- VLC

### Gaming
- Steam
- Heroic
- Bottles
- ProtonPlus

### Development tools
- Distrobox (+ DistroShelf)
- Docker
- Emacs
- Neovim

## System
- Shell: **bash** (default) or **fish**
- Logitech K380 function keys
- Remove LibreOffice
- Git identity
