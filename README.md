# Fedora 44 + niri + noctalia-shell

Automated setup script for a clean and minimal Fedora 44 workstation using [`niri`](https://github.com/YaLTeR/niri) and [`noctalia-shell`](https://github.com/noctalia-dev/noctalia-shell).

The script installs and configures a complete Wayland desktop environment with sensible defaults, including:

- Niri
- Noctalia-shell
- Kitty terminal
- Numix icon themes
- Wayland/Qt/Electron environment tweaks
- Preconfigured keybinds and desktop layout
- Optional gaming/media/software packages
- Optional development tools
- Optional git identity setup

> [!NOTE]
> The script intentionally removes most pre-installed GNOME applications to keep the system minimal. `GNOME Software` is also removed after setup. Flatpak management can be done through `Bazaar`, which is installed by default.
> - The script must be run as a regular user (not root). `sudo` is used internally when required.
> - The installer stops immediately on errors.
> - The default configuration is optimized for Wayland.

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

# Shell

During setup you can choose between **bash** (default) and **fish**.

**bash** - keeps the existing shell. Zoxide is initialized in `~/.bashrc` and environment variables are written to `~/.bash_profile`.

**fish** - installs fish, sets it as the default shell via `chsh`, and writes `~/.config/fish/config.fish` with environment variables, PATH configuration, `mise` activation, and zoxide integration.

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

## Default keyboard shortcuts

All shortcuts use the **Super** (`Mod`) key (usually the Windows key).

| Action | Shortcut |
|--------|----------|
| Terminal (kitty) | `Mod` + `Return` |
| Browser | `Mod` + `B` |
| Launcher | `Mod` + `Space` |
| Focus column left/right | `Mod` + `←` / `→` |
| Focus window down/up | `Mod` + `↓` / `↑` |
| Move column left/right | `Mod` + `Ctrl` + `←` / `→` |
| Switch workspace | `Mod` + `1` … `9` |
| Move column to workspace | `Mod` + `Ctrl` + `1` … `9` |
| Maximize column | `Mod` + `F` |
| Close window | `Mod` + `Q` |
| Quit niri | `Mod` + `Shift` + `E` |

A full list of bindings is available in `~/.config/niri/config.kdl`.

---

# Included defaults

## Core packages

- `Niri`
- `Noctalia-shell`
- `Numix Icon Themes`
- `wf-recorder` + `slurp`
- `mise` (version manager for languages, env vars, and tasks per project)
- `Zen Browser`
- `Fastfetch`
- `zoxide`
- `kitty`
- `pipx`

# Optional Applications

## DNF Packages

- qBittorrent
- OBS Studio
- Calibre
- Steam

---

## Flatpak Applications

- Heroic Games Launcher
- Libre Menu Editor
- Gear Lever
- YACReader
- ProtonPlus
- Telegram
- Spotify
- Bottles
- Anki
- VLC

---

## Optional Development Tools

- Neovim (basic setup without plugins)
- Distrobox
- Docker
