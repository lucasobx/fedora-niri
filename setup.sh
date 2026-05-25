#!/usr/bin/env bash
# =============================================================================
# setup.sh - Fedora 44 + niri + noctalia-shell
# =============================================================================
# Usage:
#   chmod +x setup.sh && ./setup.sh
#
# - Stops immediately on any error (set -euo pipefail)
# - Must be run as a regular user; sudo is invoked internally as needed
# - All optional packages are prompted interactively before installation
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

step()    { echo -e "\n${BOLD}${GREEN}==>${RESET}${BOLD} $*${RESET}"; }
info()    { echo -e "  ${CYAN}>${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}AVISO:${RESET} $*"; }
die()     { echo -e "\n${RED}ERRO:${RESET} $*" >&2; exit 1; }
divider() { echo -e "\n${BOLD}$(printf '─%.0s' {1..60})${RESET}"; }

# Ask a yes/no question; returns 0 for yes, 1 for no
ask_yn() {
    local prompt="$1"
    local answer
    while true; do
        read -rp "  ${prompt} [y/n]: " answer
        case "${answer,,}" in
            s|sim|y|yes) return 0 ;;
            n|nao|no)    return 1 ;;
            *) echo "    Please answer y or n." ;;
        esac
    done
}

[[ "$EUID" -eq 0 ]] && die "Do not run this script as root. sudo will be called internally when needed."

# =============================================================================
# Collect all user choices upfront, before any installation begins
# =============================================================================

divider
echo -e "${BOLD} Optional packages - make your choices before we begin${RESET}"
divider

# --- Optional DNF packages ---
echo -e "\n${BOLD}DNF packages:${RESET}"
OPT_QBITTORRENT=false; ask_yn "Install qBittorrent?"                                 && OPT_QBITTORRENT=true || true
OPT_CALIBRE=false;     ask_yn "Install Calibre? (e-book manager and converter)"      && OPT_CALIBRE=true     || true
OPT_STEAM=false;       ask_yn "Install Steam?"                                       && OPT_STEAM=true       || true
OPT_OBS=false;         ask_yn "Install OBS Studio?"                                  && OPT_OBS=true         || true
OPT_LOVE=false;        ask_yn "Install love? (Lua game framework)"                   && OPT_LOVE=true        || true
OPT_DISTROBOX=false;   ask_yn "Install Distrobox? (run other distros in containers)" && OPT_DISTROBOX=true   || true
OPT_VSCODE=false;      ask_yn "Install Visual Studio Code?"                          && OPT_VSCODE=true      || true
OPT_DOCKER=false;      ask_yn "Install Docker?"                                      && OPT_DOCKER=true      || true

# --- Optional Flatpaks ---
echo -e "\n${BOLD}Flatpak packages:${RESET}"
OPT_TELEGRAM=false;   ask_yn "Install Telegram? (messaging app)"                      && OPT_TELEGRAM=true   || true
OPT_VLC=false;        ask_yn "Install VLC? (versatile media player)"                  && OPT_VLC=true        || true
OPT_BAZAAR=false;     ask_yn "Install Bazaar? (GNOME app store alternative)"          && OPT_BAZAAR=true     || true
OPT_HEROIC=false;     ask_yn "Install Heroic Games Launcher?"                         && OPT_HEROIC=true     || true
OPT_LIBRE=false;      ask_yn "Install Libre Menu Editor?"                             && OPT_LIBRE=true      || true
OPT_YAC=false;        ask_yn "Install YACReader? (comic and manga reader)"            && OPT_YAC=true        || true
OPT_ANKI=false;       ask_yn "Install Anki? (flashcard-based study tool)"             && OPT_ANKI=true       || true
OPT_SPOTIFY=false;    ask_yn "Install Spotify?"                                       && OPT_SPOTIFY=true    || true
OPT_BOTTLES=false;    ask_yn "Install Bottles? (run Windows apps via Wine)"           && OPT_BOTTLES=true    || true
OPT_PROTONPLUS=false; ask_yn "Install ProtonPlus?"                                    && OPT_PROTONPLUS=true || true
OPT_FLATSEAL=false;   ask_yn "Install Flatseal? (flatpak permissions manager)"        && OPT_FLATSEAL=true   || true
OPT_FOLIATE=false;    ask_yn "Install Foliate? (e-book reader)"                       && OPT_FOLIATE=true    || true

# --- openfortivpn ---
echo -e "\n${BOLD}VPN:${RESET}"
OPT_VPN=false; ask_yn "Install openfortivpn? (FortiGate SSL VPN client)" && OPT_VPN=true || true

# --- Neovim ---
echo -e "\n${BOLD}Neovim:${RESET}"
OPT_NEOVIM=false; NEOVIM_MODE=""
if ask_yn "Install neovim?"; then
    OPT_NEOVIM=true
    echo "  Neovim setup:"
    echo "    1) Vanilla - minimal config, no plugins"
    echo "    2) LazyVim - full-featured distro with plugins"
    while true; do
        read -rp "  Select neovim setup [1/2]: " _nvim_choice
        case "$_nvim_choice" in
            1) NEOVIM_MODE="vanilla"; break ;;
            2) NEOVIM_MODE="lazyvim"; break ;;
            *) echo "    Please enter 1 or 2." ;;
        esac
    done
fi

# --- Keyboard layout ---
echo -e "\n${BOLD}Keyboard layout:${RESET}"
echo "    1) International (us/intl)"
echo "    2) ABNT (br)"
while true; do
    read -rp "  Select keyboard layout [1/2]: " _kbd_choice
    case "$_kbd_choice" in
        1) KBD_LAYOUT="us"; KBD_VARIANT='variant "intl"'; KBD_LABEL="International"; break ;;
        2) KBD_LAYOUT="br"; KBD_VARIANT="";               KBD_LABEL="ABNT";          break ;;
        *) echo "    Please enter 1 or 2." ;;
    esac
done

# --- Display profile ---
echo -e "\n${BOLD}Display (eDP-1):${RESET}"

echo "  Resolution:"
echo "    1) 2560x1600"
echo "    2) 1920x1080"
while true; do
    read -rp "  Select resolution [1/2]: " _res_choice
    case "$_res_choice" in
        1) EDP_RES="2560x1600"; break ;;
        2) EDP_RES="1920x1080"; break ;;
        *) echo "    Please enter 1 or 2." ;;
    esac
done

echo "  Refresh rate:"
echo "    1) 60Hz"
echo "    2) 144Hz"
echo "    3) 240Hz"
while true; do
    read -rp "  Select refresh rate [1/2/3]: " _hz_choice
    case "$_hz_choice" in
        1) EDP_HZ="60Hz";  break ;;
        2) EDP_HZ="144Hz"; break ;;
        3) EDP_HZ="240Hz"; break ;;
        *) echo "    Please enter 1, 2 or 3." ;;
    esac
done

echo "  Scale:"
echo "    1) 1"
echo "    2) 1.5"
echo "    3) 2"
while true; do
    read -rp "  Select scale [1/2/3]: " _scale_choice
    case "$_scale_choice" in
        1) EDP_SCALE="1";   break ;;
        2) EDP_SCALE="1.5"; break ;;
        3) EDP_SCALE="2";   break ;;
        *) echo "    Please enter 1, 2 or 3." ;;
    esac
done

# --- Git Identity (optional) ---
echo -e "\n${BOLD}Git configuration:${RESET}"
OPT_GIT=false; ask_yn "Configure Git identity?" && OPT_GIT=true || true
GIT_NAME=""; GIT_EMAIL=""
if $OPT_GIT; then
    read -rp "  Full name for Git (e.g. John Doe): " GIT_NAME
    read -rp "  Email for Git: "                     GIT_EMAIL
fi

# --- asdf (installed via Homebrew) ---
echo -e "\n${BOLD}Development tools:${RESET}"
OPT_ASDF=false; ask_yn "Install asdf? (multi-language version manager, via Homebrew)" && OPT_ASDF=true || true

# Summary before proceeding
divider
echo -e "${BOLD}  Summary — the following will be installed/configured${RESET}"
divider
echo -e "  Keyboard:      ${KBD_LABEL}"
echo -e "  Display:       eDP-1 ${EDP_RES}@${EDP_HZ} scale ${EDP_SCALE}"
echo -e "  DNF optional:  qbittorrent=${OPT_QBITTORRENT}  calibre=${OPT_CALIBRE}  steam=${OPT_STEAM}  obs=${OPT_OBS}  love=${OPT_LOVE}  distrobox=${OPT_DISTROBOX}  vscode=${OPT_VSCODE}  docker=${OPT_DOCKER}"
echo -e "  Flatpak opt:   telegram=${OPT_TELEGRAM}  vlc=${OPT_VLC}  bazaar=${OPT_BAZAAR}  heroic=${OPT_HEROIC}  libremenu=${OPT_LIBRE}  yacreader=${OPT_YAC}  anki=${OPT_ANKI}  spotify=${OPT_SPOTIFY}  bottles=${OPT_BOTTLES}  protonplus=${OPT_PROTONPLUS}  flatseal=${OPT_FLATSEAL}  foliate=${OPT_FOLIATE}"
echo -e "  Neovim:        ${OPT_NEOVIM} $(if $OPT_NEOVIM; then echo "(${NEOVIM_MODE})"; fi)"
echo -e "  asdf:          ${OPT_ASDF}"
echo -e "  VPN:           ${OPT_VPN}"
echo -e "  Git identity:  ${OPT_GIT} $(if $OPT_GIT; then echo "${GIT_NAME} <${GIT_EMAIL}>"; fi)"
echo ""
ask_yn "Proceed?" || { echo "Aborted."; exit 0; }

# =============================================================================
# Step 1 - Swap ffmpeg-free for ffmpeg full
# =============================================================================
step "1 - Swapping ffmpeg-free for ffmpeg full"
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

# =============================================================================
# Step 2 - Enable RPM Fusion repositories
# =============================================================================
step "2 - Enabling RPM Fusion repositories"
sudo dnf install -y \
    "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y \
    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf update -y

# =============================================================================
# Step 3 - Remove unwanted pre-installed packages
# =============================================================================
step "3 - Removing unwanted pre-installed packages"

# Remove LibreOffice
sudo dnf group remove -y libreoffice
sudo dnf remove -y 'libreoffice-*' || true

# Remove unwanted GNOME apps
sudo dnf remove -y \
    gnome-boxes \
    gnome-calculator \
    gnome-calendar \
    gnome-characters \
    gnome-clocks \
    gnome-connections \
    gnome-contacts \
    gnome-disk-utility \
    gnome-weather \
    gnome-maps \
    yelp \
    gnome-font-viewer \
    gnome-logs \
    gnome-system-monitor \
    gnome-text-editor \
    gnome-tour \
    showtime \
    decibels \
    baobab \
    mediawriter \
    papers \
    simple-scan \
    snapshot \
    malcontent-control \
    malcontent-tools \
    ibus-typing-booster \
    gnome-color-manager || true

# =============================================================================
# Step 4 - Install DNF packages
# =============================================================================
step "4 - Installing DNF packages"

DNF_PKGS=(
    google-noto-emoji-fonts
    google-noto-fonts-all
    adw-gtk3-theme
    gnome-tweaks
    fastfetch
    zoxide
    fuzzel
    kitty
    unrar
    unzip
    7zip
    zip
)

# libyaml-devel and libffi-devel only if asdf will be installed
$OPT_ASDF && DNF_PKGS+=(libyaml-devel libffi-devel)

# Optional packages selected earlier
$OPT_QBITTORRENT && DNF_PKGS+=(qbittorrent)
$OPT_CALIBRE     && DNF_PKGS+=(calibre)
$OPT_STEAM       && DNF_PKGS+=(steam)
$OPT_OBS         && DNF_PKGS+=(obs-studio)
$OPT_DISTROBOX   && DNF_PKGS+=(distrobox)
$OPT_LOVE        && DNF_PKGS+=(love)

sudo dnf install -y "${DNF_PKGS[@]}"

# =============================================================================
# Step 4 - Install Flatpaks
# =============================================================================
step "5 - Installing Flatpaks"

FLATPAK_PKGS=(
    org.localsend.localsend_app
    net.nokyan.Resources
)

$OPT_TELEGRAM   && FLATPAK_PKGS+=(org.telegram.desktop)
$OPT_VLC        && FLATPAK_PKGS+=(org.videolan.VLC)
$OPT_BAZAAR     && FLATPAK_PKGS+=(io.github.kolunmi.Bazaar)
$OPT_HEROIC     && FLATPAK_PKGS+=(com.heroicgameslauncher.hgl)
$OPT_LIBRE      && FLATPAK_PKGS+=(page.codeberg.libre_menu_editor.LibreMenuEditor)
$OPT_YAC        && FLATPAK_PKGS+=(com.yacreader.YACReader)
$OPT_ANKI       && FLATPAK_PKGS+=(net.ankiweb.Anki)
$OPT_SPOTIFY    && FLATPAK_PKGS+=(com.spotify.Client)
$OPT_BOTTLES    && FLATPAK_PKGS+=(com.usebottles.bottles)
$OPT_PROTONPLUS && FLATPAK_PKGS+=(com.vysp3r.ProtonPlus)
$OPT_FLATSEAL   && FLATPAK_PKGS+=(com.github.tchx84.Flatseal)
$OPT_FOLIATE    && FLATPAK_PKGS+=(com.github.johnfactotum.Foliate)
# DistroShelf is installed automatically alongside distrobox
$OPT_DISTROBOX  && FLATPAK_PKGS+=(com.ranfdev.DistroShelf)

flatpak install -y flathub "${FLATPAK_PKGS[@]}"

# =============================================================================
# Step 6 - Configure Git (optional)
# =============================================================================
if $OPT_GIT; then
    step "6 - Configuring Git"
    git config --global user.name        "$GIT_NAME"
    git config --global user.email       "$GIT_EMAIL"
    git config --global init.defaultBranch main
    git config --global core.autocrlf    input
    git config --global core.safecrlf    true
    git config --global color.ui         true
    info "Git configured for: ${GIT_NAME} <${GIT_EMAIL}>"
else
    info "Skipping step 6 (Git configuration not requested)"
fi

# =============================================================================
# Step 6 - Configure ~/.bashrc
# =============================================================================
step "7 - Configuring ~/.bashrc"

if grep -q '_ZO_DOCTOR' ~/.bashrc; then
    warn "Zoxide block already present in ~/.bashrc — skipping"
else
    cat >> ~/.bashrc << 'EOF'

# Zoxide
export _ZO_DOCTOR=0
eval "$(zoxide init bash --cmd cd)"
EOF
    info "Zoxide block added to ~/.bashrc"
fi

# =============================================================================
# Step 7 - Install niri and noctalia-shell
# =============================================================================
step "8 - Installing niri and noctalia-shell"

if ! dnf copr list --enabled 2>/dev/null | grep -q "yalter/niri"; then
    sudo dnf copr enable -y yalter/niri
else
    warn "COPR yalter/niri already enabled"
fi

if ! dnf copr list --enabled 2>/dev/null | grep -q "lionheartp/Hyprland"; then
    sudo dnf copr enable -y lionheartp/Hyprland
else
    warn "COPR lionheartp/Hyprland already enabled"
fi

sudo dnf update -y
sudo dnf install -y niri --setopt=install_weak_deps=False
sudo dnf install -y noctalia-shell

# =============================================================================
# Step 8 - Configure environment variables
# =============================================================================
step "9 - Configuring environment variables"

# Write ~/.bash_profile block (idempotent check)
if grep -q 'QT_QPA_PLATFORM' ~/.bash_profile 2>/dev/null; then
    warn "Wayland block already present in ~/.bash_profile — skipping"
else
    cat >> ~/.bash_profile << 'EOF'

# Wayland / Qt / GTK environment
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export ELECTRON_OZONE_PLATFORM_HINT=auto
export QT_QPA_PLATFORMTHEME=gtk3
export QT_QPA_PLATFORM=wayland
EOF
    info "Environment block written to ~/.bash_profile"
fi

# =============================================================================
# Step 10 - Configure fuzzel
# =============================================================================
step "11 - Configuring fuzzel"
mkdir -p ~/.config/fuzzel

cat > ~/.config/fuzzel/fuzzel.ini << 'EOF'
[main]
icon-theme=Numix-Circle
line-height=30
lines=5

[border]
radius=10
width=2

[colors]
background=1a1a1aff
text=d1d1d1ff
match=ffffffff
selection=333333ff
selection-text=ffffffff
selection-match=ffffffff
border=4d4d4dff
EOF

info "~/.config/fuzzel/fuzzel.ini created"

# =============================================================================
# Step 11 - Configure kitty
# =============================================================================
step "12 - Configuring kitty"
mkdir -p ~/.config/kitty

cat > ~/.config/kitty/kitty.conf << 'EOF'
window_margin_width 2
enable_audio_bell no
background_opacity 1
background_blur 1

# tabs
tab_bar_style powerline
tab_title_template "{title.split('/')[-1]}"
active_tab_font_style normal
inactive_tab_font_style normal

# font
bold_italic_font auto
italic_font auto
bold_font auto
font_size 12
EOF

info "~/.config/kitty/kitty.conf created"

# =============================================================================
# Step 12 - Configure neovim (optional)
# =============================================================================
if $OPT_NEOVIM; then
    step "10 (optional) - Configuring neovim (${NEOVIM_MODE})"
    sudo dnf install -y neovim
    mkdir -p ~/.config/nvim

    if [[ "$NEOVIM_MODE" == "vanilla" ]]; then
        cat > ~/.config/nvim/init.lua << 'EOF'
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.opt.clipboard = "unnamedplus"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.numberwidth = 1

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.opt.cursorline = false
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.wrap = false

vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.swapfile = false
vim.opt.undofile = true
EOF
        info "Neovim vanilla config written to ~/.config/nvim/init.lua"
    else
        # LazyVim starter
        git clone https://github.com/LazyVim/starter ~/.config/nvim
        rm -rf ~/.config/nvim/.git
        info "LazyVim starter cloned to ~/.config/nvim"
    fi
else
    info "Skipping step 13 (neovim not requested)"
fi

# =============================================================================
# Step 13 - Install wallpapers
# =============================================================================
step "13 - Installing wallpapers"

_WALL_TMP="$(mktemp -d)"
git clone https://github.com/lucasobx/fedora-niri.git "${_WALL_TMP}/fedora-niri"
mkdir -p ~/Pictures
mv "${_WALL_TMP}/fedora-niri/Wallpapers" ~/Pictures/Wallpapers
rm -rf "${_WALL_TMP}"
info "Wallpapers installed to ~/Pictures/Wallpapers"

# =============================================================================
# Step 14 - Configure niri
# =============================================================================
step "14 - Configuring niri"
mkdir -p ~/.config/niri

# Build xkb block according to keyboard choice
if [[ "$KBD_LAYOUT" == "us" ]]; then
    XKB_BLOCK='        xkb {
            layout "us"
            options "ctrl:nocaps"
            variant "intl"
        }'
else
    XKB_BLOCK='        xkb {
            layout "br"
            options "ctrl:nocaps"
        }'
fi

# Strip "Hz" suffix for niri mode format
EDP_HZ_NUM="${EDP_HZ%Hz}"

cat > ~/.config/niri/config.kdl << EOF
input {
    keyboard {
${XKB_BLOCK}
        repeat-delay 300
        repeat-rate 25
        numlock
    }

    touchpad {
        tap
        natural-scroll
    }

    mouse {}

    trackpoint {}

    warp-mouse-to-focus
    focus-follows-mouse max-scroll-amount="0%"
}

output "eDP-1" {
    mode "${EDP_RES}@${EDP_HZ_NUM}"
    scale ${EDP_SCALE}
}

layout {
    gaps 16
    center-focused-column "never"

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width { proportion 0.5; }

    focus-ring {
        width 2
        active-color "#8f98b5"
        inactive-color "#505050"
    }

    border {
        off
    }

    shadow {}
    struts {}
}

spawn-at-startup "qs" "-c" "noctalia-shell"

prefer-no-csd

hotkey-overlay {
    skip-at-startup
}

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

animations {}

blur {
    passes 5
    offset 3.0
    noise 0.03
    saturation 1.5
}

window-rule {
    match app-id="kitty"
    opacity 0.85
    background-effect {
        blur true
    }
}

window-rule {
    match app-id=r#"^org\.wezfurlong\.wezterm$"#
    default-column-width {}
}

window-rule {
    match app-id=r#"firefox$"# title="^Picture-in-Picture$"
    open-floating true
}

binds {
    Mod+Shift+Slash { show-hotkey-overlay; }

    Mod+Return { spawn "kitty"; }
    Mod+Space { spawn "fuzzel"; }
    Mod+N { spawn "nautilus"; }
    Mod+B { spawn "firefox"; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

    XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
    XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
    XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

    XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }

    Mod+O repeat=false { toggle-overview; }

    Mod+Q repeat=false { close-window; }

    Mod+Left  { focus-column-left; }
    Mod+Down  { focus-window-down; }
    Mod+Up    { focus-window-up; }
    Mod+Right { focus-column-right; }

    Mod+Ctrl+Left  { move-column-left; }
    Mod+Ctrl+Down  { move-window-down; }
    Mod+Ctrl+Up    { move-window-up; }
    Mod+Ctrl+Right { move-column-right; }

    Mod+Home { focus-column-first; }
    Mod+End  { focus-column-last; }
    Mod+Ctrl+Home { move-column-to-first; }
    Mod+Ctrl+End  { move-column-to-last; }

    Mod+Page_Down      { focus-workspace-down; }
    Mod+Page_Up        { focus-workspace-up; }
    Mod+U              { focus-workspace-down; }
    Mod+I              { focus-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
    Mod+Ctrl+U         { move-column-to-workspace-down; }
    Mod+Ctrl+I         { move-column-to-workspace-up; }

    Mod+Shift+Page_Down { move-workspace-down; }
    Mod+Shift+Page_Up   { move-workspace-up; }
    Mod+Shift+U         { move-workspace-down; }
    Mod+Shift+I         { move-workspace-up; }

    Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
    Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
    Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
    Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

    Mod+WheelScrollRight      { focus-column-right; }
    Mod+WheelScrollLeft       { focus-column-left; }
    Mod+Ctrl+WheelScrollRight { move-column-right; }
    Mod+Ctrl+WheelScrollLeft  { move-column-left; }

    Mod+Shift+WheelScrollDown      { focus-column-right; }
    Mod+Shift+WheelScrollUp        { focus-column-left; }
    Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
    Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    Mod+Ctrl+1 { move-column-to-workspace 1; }
    Mod+Ctrl+2 { move-column-to-workspace 2; }
    Mod+Ctrl+3 { move-column-to-workspace 3; }
    Mod+Ctrl+4 { move-column-to-workspace 4; }
    Mod+Ctrl+5 { move-column-to-workspace 5; }
    Mod+Ctrl+6 { move-column-to-workspace 6; }
    Mod+Ctrl+7 { move-column-to-workspace 7; }
    Mod+Ctrl+8 { move-column-to-workspace 8; }
    Mod+Ctrl+9 { move-column-to-workspace 9; }

    Mod+Tab { focus-workspace-previous; }

    Mod+BracketLeft  { consume-or-expel-window-left; }
    Mod+BracketRight { consume-or-expel-window-right; }

    Mod+Comma  { consume-window-into-column; }
    Mod+Period { expel-window-from-column; }

    Mod+R { switch-preset-column-width; }
    Mod+Shift+R { switch-preset-column-width-back; }

    Mod+Ctrl+Shift+R { switch-preset-window-height; }
    Mod+Ctrl+R { reset-window-height; }

    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    Mod+M { maximize-window-to-edges; }

    Mod+Ctrl+F { expand-column-to-available-width; }

    Mod+C { center-column; }

    Mod+Ctrl+C { center-visible-columns; }

    Mod+Minus { set-column-width "-10%"; }
    Mod+Equal { set-column-width "+10%"; }

    Mod+Shift+Minus { set-window-height "-10%"; }
    Mod+Shift+Equal { set-window-height "+10%"; }

    Mod+V       { toggle-window-floating; }
    Mod+Shift+V { switch-focus-between-floating-and-tiling; }

    Mod+W { toggle-column-tabbed-display; }

    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

    Mod+Shift+E { quit; }
    Ctrl+Alt+Delete { quit; }

    Mod+Shift+P { power-off-monitors; }
}
EOF

info "~/.config/niri/config.kdl created"

# =============================================================================
# Step 16 - Install and configure Numix icons + themes
# =============================================================================
step "16 - Installing Numix icons and configuring themes"

_NUMIX_TMP="$(mktemp -d)"
cd "$_NUMIX_TMP"

git clone https://github.com/numixproject/numix-icon-theme
git clone https://github.com/numixproject/numix-icon-theme-circle
git clone https://github.com/numixproject/numix-folders

sudo mv numix-icon-theme/Numix /usr/share/icons/
sudo mv numix-icon-theme/Numix-Light /usr/share/icons/
sudo mv numix-icon-theme-circle/Numix-Circle /usr/share/icons/
sudo mv numix-icon-theme-circle/Numix-Circle-Light /usr/share/icons/
sudo mv numix-folders /usr/share/icons/

rm -rf numix-icon-theme numix-icon-theme-circle

cd ~
rm -rf "$_NUMIX_TMP"

# Apply Numix-Circle icon theme
gsettings set org.gnome.desktop.interface icon-theme "Numix-Circle"
info "Icon theme set to Numix-Circle"

# Apply numix-folders with style 5 and color grey
cd /usr/share/icons/numix-folders
printf '5\ngrey\n' | sudo ./numix-folders -t
cd ~
info "numix-folders configured (style 5, grey)"

# Apply dark color scheme
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
info "Color scheme set to prefer-dark"

# Apply Adw-gtk3-dark legacy application theme
gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
info "Legacy application theme set to adw-gtk3-dark"

# =============================================================================
# Step 16 - Install openfortivpn (optional)
# =============================================================================
if $OPT_VPN; then
    step "17 - Installing openfortivpn"
    sudo dnf install -y openfortivpn
    sudo mkdir -p /etc/openfortivpn

    # Create config file with commented placeholders
    sudo tee /etc/openfortivpn/config > /dev/null << 'EOF'
#host =
#port =
#username =
#password =
EOF
    info "Config created at /etc/openfortivpn/config"

    # Add VPN aliases to ~/.bashrc (idempotent)
    if grep -q 'alias vpn=' ~/.bashrc; then
        warn "VPN aliases already present in ~/.bashrc — skipping"
    else
        cat >> ~/.bashrc << 'EOF'

# openfortivpn aliases
alias vpn='sudo nohup openfortivpn >/tmp/openfortivpn.log 2>&1 &'
alias vpnlog='tail -f /tmp/openfortivpn.log'
alias vpnx='sudo pkill openfortivpn'
EOF
        info "VPN aliases added to ~/.bashrc"
    fi
else
    info "Skipping step 16 (openfortivpn not requested)"
fi

# =============================================================================
# Step 17 - Install Visual Studio Code (optional)
# =============================================================================
if $OPT_VSCODE; then
    step "18 - Installing Visual Studio Code"
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
        | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    sudo dnf check-update || true
    sudo dnf install -y code
    info "Visual Studio Code installed"
else
    info "Skipping step 18 (VS Code not requested)"
fi

# =============================================================================
# Step 19 - Install Docker (optional)
# =============================================================================
if $OPT_DOCKER; then
    step "19 - Installing Docker"
    sudo dnf config-manager addrepo \
        --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    info "Docker installed"
else
    info "Skipping step 19 (Docker not requested)"
fi

# =============================================================================
# Step 20 - Install Homebrew + gcc
# =============================================================================
step "20 - Installing Homebrew"

if command -v brew &>/dev/null; then
    warn "Homebrew already installed — skipping"
else
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH in ~/.bashrc (idempotent)
    if grep -q 'linuxbrew' ~/.bashrc; then
        warn "Homebrew block already present in ~/.bashrc — skipping"
    else
        echo "" >> ~/.bashrc
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> ~/.bashrc
    fi

    # Load brew into current shell session
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"

    brew install gcc
    info "Homebrew and gcc installed"

    # Install asdf if requested
    if $OPT_ASDF; then
        brew install asdf
        # Add asdf shims to PATH in ~/.bashrc (idempotent)
        if grep -q 'ASDF_DATA_DIR' ~/.bashrc; then
            warn "asdf shims block already present in ~/.bashrc — skipping"
        else
            echo "" >> ~/.bashrc
            echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> ~/.bashrc
        fi
        info "asdf installed and shims added to ~/.bashrc"
    fi
fi

# =============================================================================
# Step 21 - System update, cleanup, and reboot
# =============================================================================
step "21 - System update and cleanup"
sudo dnf upgrade -y
sudo dnf remove -y rygel
sudo dnf clean all
sudo dnf autoremove -y

# =============================================================================
# Done
# =============================================================================
divider
echo -e "${BOLD}${GREEN}  ✓ Setup complete${RESET}"
divider
echo ""
if $OPT_GIT; then
    echo -e "${BOLD}  Git / SSH:${RESET}"
    echo -e "  Git was configured for: ${GIT_NAME} <${GIT_EMAIL}>"
    echo -e "  To create an SSH key, run:"
    echo -e "    ${CYAN}ssh-keygen -t ed25519 -C \"${GIT_EMAIL}\"${RESET}"
    echo ""
fi
if $OPT_VPN; then
    echo -e "${BOLD}  openfortivpn usage:${RESET}"
    echo -e "  Fill in your credentials at: ${CYAN}/etc/openfortivpn/config${RESET}"
    echo -e "  Then use the following aliases (available after reboot/re-login):"
    echo -e "    ${CYAN}vpn${RESET}     — connect"
    echo -e "    ${CYAN}vpnlog${RESET}  — follow the connection log"
    echo -e "    ${CYAN}vpnx${RESET}    — disconnect"
    echo ""
fi
if $OPT_DOCKER; then
    echo -e "${BOLD}  Docker:${RESET}"
    echo -e "  Docker was installed but not started. To enable and start it, run:"
    echo -e "    ${CYAN}sudo systemctl enable --now docker${RESET}"
    echo -e "  For more information: ${CYAN}https://docs.docker.com/engine/install/fedora${RESET}"
    echo ""
fi
ask_yn "Reboot now?" && sudo reboot || echo -e "\n  Reboot skipped. Remember to reboot before starting niri."
