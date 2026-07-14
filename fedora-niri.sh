#!/usr/bin/env bash
# =============================================================================
# Fedora 44 + Niri + Noctalia-shell
# =============================================================================
# usage:
# chmod +x fedora-niri.sh && ./fedora-niri.sh
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

# Keep sudo session alive during script execution
sudo -v
while true; do sudo -v; sleep 60; done &
_SUDO_PID=$!
trap 'kill "$_SUDO_PID" 2>/dev/null' EXIT

# =============================================================================
# Collect all user choices upfront, before any installation begins
# =============================================================================

divider
echo -e "${BOLD} Optional packages - make your choices before we begin${RESET}"
divider

# --- Optional Packages ---
echo -e "\n${BOLD}DNF packages:${RESET}"
OPT_QBITTORRENT=false; ask_yn "Install qBittorrent?" && OPT_QBITTORRENT=true || true
OPT_OBS=false;         ask_yn "Install OBS Studio?"  && OPT_OBS=true         || true
OPT_DISTROBOX=false;   ask_yn "Install Distrobox?"   && OPT_DISTROBOX=true   || true
OPT_DOCKER=false;      ask_yn "Install Docker?"      && OPT_DOCKER=true      || true
OPT_NEOVIM=false;      ask_yn "Install Neovim?"      && OPT_NEOVIM=true      || true
OPT_EMACS=false;       ask_yn "Install Emacs?"       && OPT_EMACS=true       || true
OPT_STEAM=false;       ask_yn "Install Steam?"       && OPT_STEAM=true       || true

# --- Optional Flatpaks ---
echo -e "\n${BOLD}Flatpak packages:${RESET}"
OPT_BOTTLES=false;    ask_yn "Install Bottles? (Install Windows apps via Wine)" && OPT_BOTTLES=true    || true
OPT_GEARLEVER=false;  ask_yn "Install Gear Lever? (AppImage manager)"           && OPT_GEARLEVER=true  || true
OPT_HEROIC=false;     ask_yn "Install Heroic Games Launcher?"                   && OPT_HEROIC=true     || true
OPT_PROTONPLUS=false; ask_yn "Install ProtonPlus?"                              && OPT_PROTONPLUS=true || true
OPT_TELEGRAM=false;   ask_yn "Install Telegram?"                                && OPT_TELEGRAM=true   || true
OPT_SPOTIFY=false;    ask_yn "Install Spotify?"                                 && OPT_SPOTIFY=true    || true

# --- Video player ---
echo -e "\n${BOLD}Video player:${RESET}"
echo "    1) VLC"
echo "    2) GNOME Videos"
OPT_VLC=false; OPT_TOTEM=false
while true; do
  read -rp "  Select video player [1/2]: " _vid_choice
  case "$_vid_choice" in
    1) OPT_VLC=true;   break ;;
    2) OPT_TOTEM=true; break ;;
    *) echo "    Please enter 1 or 2." ;;
  esac
done

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

# --- Logitech K380 ---
echo -e "\n${BOLD}Logitech K380:${RESET}"
OPT_K380=false; ask_yn "Do you own a Logitech K380 keyboard? (enable standard F keys)" && OPT_K380=true || true

# --- Display profile ---
echo -e "\n${BOLD}Display (eDP-1):${RESET}"

echo "  Resolution:"
echo "    1) 1920x1080"
echo "    2) 2560x1440"
echo "    3) 2560x1600"
echo "    4) 3840x2160"
while true; do
  read -rp "  Select resolution [1/2/3/4]: " _res_choice
  case "$_res_choice" in
    1) EDP_RES="1920x1080"; break ;;
    2) EDP_RES="2560x1440"; break ;;
    3) EDP_RES="2560x1600"; break ;;
    4) EDP_RES="3840x2160"; break ;;
    *) echo "    Please enter 1, 2, 3 or 4." ;;
  esac
done

echo "  Refresh rate:"
echo "    1) 60Hz"
echo "    2) 75Hz"
echo "    3) 90Hz"
echo "    4) 120Hz"
echo "    5) 144Hz"
echo "    6) 165Hz"
echo "    7) 240Hz"
while true; do
  read -rp "  Select refresh rate [1/2/3/4/5/6/7]: " _hz_choice
  case "$_hz_choice" in
    1) EDP_HZ="60Hz";  break ;;
    2) EDP_HZ="75Hz";  break ;;
    3) EDP_HZ="90Hz";  break ;;
    4) EDP_HZ="120Hz"; break ;;
    5) EDP_HZ="144Hz"; break ;;
    6) EDP_HZ="165Hz"; break ;;
    7) EDP_HZ="240Hz"; break ;;
    *) echo "    Please enter 1 through 7." ;;
  esac
done

echo "  Scale:"
echo "    1) 100%"
echo "    2) 125%"
echo "    3) 133%"
echo "    4) 150%"
echo "    5) 166%"
echo "    6) 200%"
while true; do
  read -rp "  Select scale [1/2/3/4/5/6]: " _scale_choice
  case "$_scale_choice" in
    1) EDP_SCALE="1";        break ;;
    2) EDP_SCALE="1.25";     break ;;
    3) EDP_SCALE="1.333333"; break ;;
    4) EDP_SCALE="1.5";      break ;;
    5) EDP_SCALE="1.666667"; break ;;
    6) EDP_SCALE="2";        break ;;
    *) echo "    Please enter 1 through 6." ;;
  esac
done

# --- Git Identity (optional) ---
echo -e "\n${BOLD}Git configuration:${RESET}"
OPT_GIT=false; ask_yn "Configure Git identity?" && OPT_GIT=true || true
GIT_NAME=""; GIT_EMAIL=""
if $OPT_GIT; then
  read -rp "  Full name for git: " GIT_NAME
  read -rp "  Email for git: "     GIT_EMAIL
fi

# --- Shell ---
echo -e "\n${BOLD}Shell:${RESET}"
echo "    1) bash (keep as default)"
echo "    2) fish"
while true; do
  read -rp "  Select shell [1/2]: " _shell_choice
  case "$_shell_choice" in
    1) SHELL_CHOICE="bash"; break ;;
    2) SHELL_CHOICE="fish"; break ;;
    *) echo "    Please enter 1 or 2." ;;
  esac
done

# --- Remove LibreOffice? ---
echo -e "\n${BOLD}LibreOffice removal:${RESET}"
OPT_REMOVE_LIBREOFFICE=false; ask_yn "Remove LibreOffice (pre-installed)?" && OPT_REMOVE_LIBREOFFICE=true || true

divider
echo -e "${BOLD}  Summary — the following will be installed/configured${RESET}"
divider
echo -e "  Keyboard:      ${KBD_LABEL}"
echo -e "  Logitech K380: ${OPT_K380}"
echo -e "  Display:       eDP-1 ${EDP_RES}@${EDP_HZ} scale ${EDP_SCALE}"
echo -e "  DNF opt:       qbittorrent=${OPT_QBITTORRENT} steam=${OPT_STEAM} obs=${OPT_OBS} distrobox=${OPT_DISTROBOX} docker=${OPT_DOCKER} neovim=${OPT_NEOVIM} emacs=${OPT_EMACS}"
echo -e "  Flatpak opt:   telegram=${OPT_TELEGRAM} heroic=${OPT_HEROIC} spotify=${OPT_SPOTIFY} bottles=${OPT_BOTTLES} protonplus=${OPT_PROTONPLUS} gearlever=${OPT_GEARLEVER}"
echo -e "  Video player:  $(if $OPT_VLC; then echo "vlc (flatpak)"; else echo "totem (dnf)"; fi)"
echo -e "  Shell:         ${SHELL_CHOICE}"
echo -e "  Git identity:  ${OPT_GIT} $(if $OPT_GIT; then echo "${GIT_NAME} <${GIT_EMAIL}>"; fi)"
echo -e "  Remove LibreOffice: ${OPT_REMOVE_LIBREOFFICE}"
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

if $OPT_REMOVE_LIBREOFFICE; then
  sudo dnf group remove -y libreoffice
  sudo dnf remove -y 'libreoffice-*' || true
fi

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
  gnome-color-manager \
  gnome-software || true

# Remove unwanted third-party repositories
sudo rm -f /etc/yum.repos.d/google-chrome.repo
sudo dnf copr remove -y phracek/PyCharm || true

# =============================================================================
# Step 4 - Install DNF packages
# =============================================================================
step "4 - Installing DNF packages"

DNF_PKGS=(
  google-noto-emoji-fonts
  google-noto-fonts-all
  adw-gtk3-theme
  gnome-tweaks
  wf-recorder
  fastfetch
  fd-find
  zoxide
  kitty
  slurp
  unzip
  unrar
  7zip
  zip
)

$OPT_QBITTORRENT && DNF_PKGS+=(qbittorrent)
$OPT_OBS         && DNF_PKGS+=(obs-studio)
$OPT_DISTROBOX   && DNF_PKGS+=(distrobox)
$OPT_STEAM       && DNF_PKGS+=(steam)
$OPT_EMACS       && DNF_PKGS+=(emacs)
$OPT_TOTEM       && DNF_PKGS+=(totem)

# Enable mise COPR and add to install list
if ! dnf copr list --enabled 2>/dev/null | grep -q "jdxcode/mise"; then
  sudo dnf copr enable -y jdxcode/mise
else
  warn "COPR jdxcode/mise already enabled"
fi
DNF_PKGS+=(mise)

# Enable Zen Browser COPR and add to install list
if ! dnf copr list --enabled 2>/dev/null | grep -q "sneexy/zen-browser"; then
  sudo dnf copr enable -y sneexy/zen-browser
else
  warn "COPR sneexy/zen-browser already enabled"
fi
DNF_PKGS+=(zen-browser)

sudo dnf install -y "${DNF_PKGS[@]}"

step "Installing pipx"
sudo dnf install -y pipx
pipx ensurepath

# =============================================================================
# Step 5 - Install Flatpaks
# =============================================================================
step "5 - Installing Flatpaks"

FLATPAK_PKGS=(
  page.codeberg.libre_menu_editor.LibreMenuEditor
  org.localsend.localsend_app
  io.github.kolunmi.Bazaar
  net.nokyan.Resources
)

$OPT_HEROIC     && FLATPAK_PKGS+=(com.heroicgameslauncher.hgl)
$OPT_DISTROBOX  && FLATPAK_PKGS+=(com.ranfdev.DistroShelf)
$OPT_BOTTLES    && FLATPAK_PKGS+=(com.usebottles.bottles)
$OPT_PROTONPLUS && FLATPAK_PKGS+=(com.vysp3r.ProtonPlus)
$OPT_TELEGRAM   && FLATPAK_PKGS+=(org.telegram.desktop)
$OPT_GEARLEVER  && FLATPAK_PKGS+=(it.mijorus.gearlever)
$OPT_SPOTIFY    && FLATPAK_PKGS+=(com.spotify.Client)
$OPT_VLC        && FLATPAK_PKGS+=(org.videolan.VLC)

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
# Step 7 - Configure shell
# =============================================================================
if [[ "$SHELL_CHOICE" == "bash" ]]; then
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

  if grep -q 'mise activate bash' ~/.bashrc; then
    warn "mise block already present in ~/.bashrc — skipping"
  else
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
    info "mise activation added to ~/.bashrc"
  fi
else
  step "7 - Installing and configuring fish shell"
  sudo dnf install -y fish
  command -v fish | sudo tee -a /etc/shells
  chsh -s "$(command -v fish)"
  mkdir -p ~/.config/fish
  cat > ~/.config/fish/config.fish << 'EOF'
# Wayland / Qt / GTK environment
set -gx QT_WAYLAND_DISABLE_WINDOWDECORATION 1
set -gx ELECTRON_OZONE_PLATFORM_HINT auto
set -gx QT_QPA_PLATFORMTHEME gtk3
set -gx QT_QPA_PLATFORM wayland
fish_add_path $HOME/.local/bin $HOME/bin
/usr/bin/mise activate fish | source
if status is-interactive
    if command -v zoxide > /dev/null
        zoxide init fish --cmd cd | source
    end
    set -U fish_greeting ""
end
EOF
  info "fish installed, set as default shell, and ~/.config/fish/config.fish written"
fi

# =============================================================================
# Step 8 - Install niri and noctalia-shell
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
sudo dnf install -y noctalia-git

# =============================================================================
# Step 9 - Configure environment variables
# =============================================================================
if [[ "$SHELL_CHOICE" == "bash" ]]; then
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
else
  info "Skipping step 9 (fish selected — env vars already in ~/.config/fish/config.fish)"
fi

# =============================================================================
# Step 11 - Configure kitty
# =============================================================================
step "11 - Configuring kitty"
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
  step "12 - Configuring neovim"
  sudo dnf install -y neovim
  mkdir -p ~/.config/nvim

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
  info "Neovim config written to ~/.config/nvim/init.lua"
else
  info "Skipping step 12 (neovim not requested)"
fi

# =============================================================================
# Step 13 - Install wallpapers
# =============================================================================
step "13 - Installing wallpapers"

mkdir -p ~/Pictures
mv ~/fedora-niri/Wallpapers ~/Pictures/Wallpapers
info "Wallpapers installed to ~/Pictures/Wallpapers"

# =============================================================================
# Step 14 - Configure niri
# =============================================================================
step "14 - Configuring niri"
mkdir -p ~/.config/niri

# Build xkb block according to keyboard choice
if [[ -n "$KBD_VARIANT" ]]; then
  XKB_BLOCK="    xkb {
      layout \"${KBD_LAYOUT}\"
      options \"ctrl:nocaps\"
      ${KBD_VARIANT}
    }"
else
  XKB_BLOCK="    xkb {
      layout \"${KBD_LAYOUT}\"
      options \"ctrl:nocaps\"
    }"
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

spawn-at-startup "noctalia"

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

  Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
  Mod+G { spawn "~/.local/bin/record-region.sh"; }
  Mod+B { spawn "zen-browser"; }
  Mod+Return { spawn "kitty"; }
  Mod+N { spawn "nautilus"; }

  XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
  XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
  XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
  XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

  XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
  XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
  XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
  XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

  XF86MonBrightnessUp allow-when-locked=true { spawn-sh "noctalia msg brightness-up"; }
  XF86MonBrightnessDown allow-when-locked=true { spawn-sh "noctalia msg brightness-down"; }

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
# Step 15 - Install local scripts and configure MIME handling
# =============================================================================

# Screen-region recording toggle (wf-recorder + slurp)
cat > ~/.local/bin/record-region.sh << 'EOF'
#!/usr/bin/env bash

if pgrep -x wf-recorder >/dev/null; then
  pkill -INT wf-recorder
  exit 0
fi

mkdir -p "$HOME/Downloads"

OUT="$HOME/Downloads/$(date +'%y%m%d-%H%M%S').mp4"

GEOMETRY="$(slurp)" || exit 0

wf-recorder -c h264_nvenc -p cq=15 -r 60 -g "$GEOMETRY" -f "$OUT"

notify-send -t 1200 "Saved"
EOF
chmod +x ~/.local/bin/record-region.sh
info "record-region.sh written to ~/.local/bin/record-region.sh"

# Ensure ~/.config/mimeapps.list exists as a file (never a directory)
[[ -d ~/.config/mimeapps.list ]] && rm -rf ~/.config/mimeapps.list
touch ~/.config/mimeapps.list
info "~/.config/mimeapps.list ensured as an empty file"

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

gsettings set org.gnome.desktop.interface icon-theme "Numix-Circle"
info "Icon theme set to Numix-Circle"

cd /usr/share/icons/numix-folders
printf '5\ngrey\n' | sudo ./numix-folders -t
cd ~
info "numix-folders configured (style 5, grey)"

gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
info "Color scheme set to prefer-dark"

gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
info "Legacy application theme set to adw-gtk3-dark"

# =============================================================================
# Step 17 - Install Docker (optional)
# =============================================================================
if $OPT_DOCKER; then
  step "17 - Installing Docker"
  sudo dnf config-manager addrepo \
    --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER"
  info "Docker installed, service enabled and started"
  info "User '$USER' added to the docker group (takes effect after next login)"
else
  info "Skipping step 17 (Docker not requested)"
fi

# =============================================================================
# Step 18 - Install and configure Monique
# =============================================================================
step "18 - Installing and configuring monique (Wayland monitor profile manager)"
pipx install monique --system-site-packages

mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/monique.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Monique
Comment=Wayland monitor profile manager
Exec=/usr/bin/env monique
Icon=preferences-desktop-display-randr
Terminal=false
Categories=Settings;System;
StartupNotify=true
Hidden=false
EOF
info "monique installed and desktop entry created at ~/.local/share/applications/monique.desktop"

# =============================================================================
# Step 19 - Disable split-lock mitigation
# =============================================================================
step "18 - Disabling split-lock mitigation"
echo 'kernel.split_lock_mitigate=0' | sudo tee /etc/sysctl.d/99-splitlock.conf > /dev/null
sudo sysctl -p /etc/sysctl.d/99-splitlock.conf
info "Split-lock mitigation disabled (/etc/sysctl.d/99-splitlock.conf)"

# =============================================================================
# Step 20 - Configure Logitech K380 function keys (optional)
# =============================================================================
if $OPT_K380; then
  step "20 - Configuring Logitech K380 function keys"
  _K380_TMP="$(mktemp -d)"
  curl -fsSL -o "$_K380_TMP/k380.zip" \
    https://github.com/jergusg/k380-function-keys-conf/archive/refs/tags/v1.1.zip
  unzip -q "$_K380_TMP/k380.zip" -d "$_K380_TMP"
  _K380_DIR="$_K380_TMP/k380-function-keys-conf-1.1"
  chmod +x "$_K380_DIR"/*.sh 2>/dev/null || true

  ( cd "$_K380_DIR" && sudo make install && sudo make reload )
  info "k380_conf installed and udev rule registered (persists across reconnects)"

  # Apply immediately if the keyboard is connected now
  _K380_DEV="$( (cd "$_K380_DIR" && sudo ./fn_on.sh 2>&1 || true) | grep -oE 'hidraw[0-9]+' | head -n1)"
  if [[ -n "$_K380_DEV" ]]; then
    sudo k380_conf -d "/dev/$_K380_DEV" -f on \
      && info "F keys enabled on /dev/$_K380_DEV" \
      || warn "k380_conf failed; reconnect the keyboard to apply automatically"
  else
    info "K380 not connected now; F keys will be enabled automatically when it connects"
  fi

  rm -rf "$_K380_TMP"
else
  info "Skipping step 20 (Logitech K380 not requested)"
fi

# =============================================================================
# Step 21 - System update, cleanup, and reboot
# =============================================================================
step "21 - System update and cleanup"
sudo dnf upgrade -y
sudo dnf remove -y rygel firefox
sudo dnf clean all
sudo dnf autoremove -y

# =============================================================================
# Done
# =============================================================================
divider
echo -e "${BOLD}${GREEN}  Setup complete${RESET}"
divider
echo ""
if $OPT_GIT; then
  echo -e "${BOLD}  Git / SSH:${RESET}"
  echo -e "  Git was configured for: ${GIT_NAME} <${GIT_EMAIL}>"
  echo -e "  To create an SSH key, run:"
  echo -e "    ${CYAN}ssh-keygen -t ed25519 -C \"${GIT_EMAIL}\"${RESET}"
  echo ""
fi
ask_yn "Reboot now?" && sudo reboot || echo -e "\n  Reboot skipped. Remember to reboot before starting niri."
