# Fedora 44 + niri + noctalia-shell

Automated setup script for a clean and minimal Fedora 44 workstation using [`niri`](https://github.com/YaLTeR/niri) and [`noctalia-shell`](https://github.com/noctalia-dev/noctalia-shell).

The script installs and configures a complete Wayland desktop environment with sensible defaults, including:

- `niri` dynamic scrollable tiling compositor
- `noctalia-shell`
- `kitty` terminal
- `fuzzel` application launcher
- Numix icon themes
- Dark GTK theme enabled
- Wayland/Qt/Electron environment tweaks
- Blur and transparency enabled in `niri`
- Preconfigured `niri` keybinds and desktop layout
- Optional development tooling (`neovim`, `asdf`, Docker, VS Code)
- Optional gaming/media/software packages via DNF and Flatpak
- Optional Git identity setup
- Display, keyboard layout, and scaling configuration during setup

The installer is fully interactive and lets you choose optional packages before installation starts.

---

# Installation

## 1. Create a bootable USB drive

Create a bootable USB using either:

- `Ventoy`
- `Fedora Media Writer`

Use the [**Fedora Everything 44**](https://fedoraproject.org/misc/#everything) ISO.

During installation:

- Select:
  - `Fedora Workstation`
- Enable:
  - `C Development Tools and Libraries`
  - `Development Tools`

---

## 2. Enable third-party repositories and update the system

After the first boot:

1. Open **GNOME Software**
2. Enable:
   - `Third Party Software Repositories`
3. Run:

```bash
sudo dnf upgrade
```

---

## 3. Clone and run the setup script

Clone the repository:

```bash
git clone https://github.com/lucasobx/fedora-niri.git ~/fedora-niri
```

Enter the directory:

```bash
cd ~/fedora-niri
```

Run the installer:

```bash
chmod +x setup.sh && ./setup.sh
```

After installation finishes:

1. Reboot the system
2. At GDM, select the `niri` session before logging in

---

# Required post-install configuration

After logging into `niri`, some `noctalia-shell` settings must be enabled manually.

## Configure idle management

1. Right-click the top bar
2. Open:
   - `Settings`
3. Navigate to:
   - `Idle`
4. Enable:
   - `Enable idle management`

## Install required plugins

1. Right-click the top bar
2. Open:
   - `Settings`
3. Navigate to:
   - `Plugins`
   - `Available`

Install:

- `Polkit Agent`

Optional:

- `Network Manager VPN` (if you use VPNs)

---

# Optional cleanup

If you do not plan to use the GNOME terminal (`ptyxis`), remove it:

```bash
sudo dnf remove ptyxis
```

---

# Steam H.264 codec support

If you installed Steam, enable H.264 codec support in the client.

## Steps

Close Steam completely, then run:

```bash
steam steam://unlockh264/
```

Steam will launch automatically.

After the process finishes:

1. Close Steam again
2. Launch Steam normally

---

# Notes

- The script must be run as a regular user (not root)
- `sudo` is used internally when required
- The installer stops immediately on errors
- The default configuration is optimized for Wayland usage

---

# Included defaults

## Core packages

- `niri`
- `noctalia-shell`
- `kitty`
- `fuzzel`
- `fastfetch`
- `zoxide`
- `pipx`
- `Numix icon themes`
