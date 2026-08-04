#!/usr/bin/env bash
# =============================================================================
# Fedora 44 + Niri + Noctalia-shell
# =============================================================================
# Run interactively; every step runs now, in order, in this one process.
#   ./fedora-niri.sh          run everything
#   ./fedora-niri.sh --fresh  wipe saved state/answers and start clean
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' CYAN='' RED='' RESET=''
fi

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

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
FRESH=false
for _arg in "$@"; do
  case "$_arg" in
    --fresh)   FRESH=true ;;
    --help|-h)
      cat <<'HELP'
Usage:
  ./fedora-niri.sh          run everything now, interactively
  ./fedora-niri.sh --fresh  wipe saved state/answers and start clean
  ./fedora-niri.sh --help   show this help
HELP
      exit 0 ;;
    *) die "Unknown argument: $_arg (try --help)" ;;
  esac
done

if [[ "$EUID" -eq 0 ]]; then
  die "Do not run this as root - run it as your normal user; it uses sudo where needed."
fi

# -----------------------------------------------------------------------------
# Shared locations and step state
# -----------------------------------------------------------------------------
_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$_SCRIPT_DIR/assets" ]]; then
  ASSETS_DIR="$_SCRIPT_DIR/assets"
else
  ASSETS_DIR="$HOME/fedora-niri/assets"
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-niri"
ANSWERS="$STATE_DIR/answers.env"

if $FRESH; then rm -rf "$STATE_DIR"; fi
mkdir -p "$STATE_DIR"

# pending <id>: returns 0 (run) if this step is not yet done, 1 (skip) if it is.
pending() {
  if [[ -e "$STATE_DIR/$1.done" ]]; then
    info "Step $1 already completed - skipping"
    return 1
  fi
  return 0
}
mark_done() { touch "$STATE_DIR/$1.done"; }

if ! $FRESH; then
  _done_count=$(find "$STATE_DIR" -maxdepth 1 -name '*.done' 2>/dev/null | wc -l)
  if [[ "$_done_count" -gt 0 ]]; then
    info "Resuming - $_done_count step(s) already completed will be skipped (use --fresh to start over)"
  fi
fi

# -----------------------------------------------------------------------------
# Network gate and setup-time preflight
# -----------------------------------------------------------------------------
_require_network() {
  info "Waiting for network before the heavy install..."
  if command -v nm-online &>/dev/null; then nm-online -q -t 60 || true; fi
  local i
  for ((i=1; i<=30; i++)); do
    if getent hosts mirrors.fedoraproject.org &>/dev/null; then
      info "Network is up."
      return 0
    fi
    sleep 3
  done
  die "No network after ~150s; aborting - fix network and re-run."
}

# -----------------------------------------------------------------------------
# Temp root + cleanup
# -----------------------------------------------------------------------------
TMP_ROOT="$(mktemp -d)"
sudo -v
while true; do sudo -v; sleep 60; done &
_SUDO_PID=$!
_cleanup() {
  trap - EXIT INT TERM
  if [[ -n "${_SUDO_PID:-}" ]]; then kill "$_SUDO_PID" 2>/dev/null || true; fi
  if [[ -n "${TMP_ROOT:-}" ]]; then rm -rf "$TMP_ROOT" 2>/dev/null || true; fi
}
trap '_cleanup' EXIT
trap '_cleanup; exit 130' INT
trap '_cleanup; exit 143' TERM

# -----------------------------------------------------------------------------
# Answers: collect / save / stage
# -----------------------------------------------------------------------------
save_answers() {
  declare -p \
    OPT_QBITTORRENT OPT_OBS OPT_DISTROBOX OPT_DOCKER OPT_NEOVIM OPT_EMACS \
    OPT_STEAM OPT_GAMEMODE OPT_BOTTLES OPT_GEARLEVER OPT_RESOURCES OPT_HEROIC \
    OPT_PROTONPLUS OPT_TELEGRAM OPT_SPOTIFY OPT_K380 OPT_REMOVE_LIBREOFFICE \
    KBD_LAYOUT KBD_VARIANT KBD_LABEL EDP_SCALE OPT_GIT GIT_NAME GIT_EMAIL \
    GPU_VENDOR HAS_INTEL_IGPU NVIDIA_BRANCH TARGET_USER > "$1"
}

collect_answers() {
  TARGET_USER="$USER"

  divider
  echo -e "${BOLD} Optional packages - make your choices before we begin${RESET}"
  divider

  # --- Optional Packages ---
  echo -e "\n${BOLD}DNF packages:${RESET}"
  OPT_GAMEMODE=false;    ask_yn "GameMode + MangoHud?" && OPT_GAMEMODE=true    || true
  OPT_QBITTORRENT=false; ask_yn "qBittorrent?"         && OPT_QBITTORRENT=true || true
  OPT_OBS=false;         ask_yn "OBS Studio?"          && OPT_OBS=true         || true
  OPT_DISTROBOX=false;   ask_yn "Distrobox?"           && OPT_DISTROBOX=true   || true
  OPT_DOCKER=false;      ask_yn "Docker?"              && OPT_DOCKER=true      || true
  OPT_NEOVIM=false;      ask_yn "Neovim?"              && OPT_NEOVIM=true      || true
  OPT_EMACS=false;       ask_yn "Emacs?"               && OPT_EMACS=true       || true
  OPT_STEAM=false;       ask_yn "Steam?"               && OPT_STEAM=true       || true

  # --- Optional Flatpaks ---
  echo -e "\n${BOLD}Flatpak packages:${RESET}"
  OPT_GEARLEVER=false;  ask_yn "Gear Lever? (appimage manager)" && OPT_GEARLEVER=true  || true
  OPT_RESOURCES=false;  ask_yn "Resources? (system monitor)"    && OPT_RESOURCES=true  || true
  OPT_BOTTLES=false;    ask_yn "Bottles? (wine front-end)"      && OPT_BOTTLES=true    || true
  OPT_HEROIC=false;     ask_yn "Heroic Games Launcher?"         && OPT_HEROIC=true     || true
  OPT_PROTONPLUS=false; ask_yn "ProtonPlus?"                    && OPT_PROTONPLUS=true || true
  OPT_TELEGRAM=false;   ask_yn "Telegram?"                      && OPT_TELEGRAM=true   || true
  OPT_SPOTIFY=false;    ask_yn "Spotify?"                       && OPT_SPOTIFY=true    || true

  # --- Graphics drivers (auto-detected) ---
  echo -e "\n${BOLD}Graphics drivers:${RESET}"
  _GPU_IDS=""
  for _d in /sys/bus/pci/devices/*; do
    _cls="$(cat "$_d/class" 2>/dev/null)" || continue
    case "$_cls" in 0x0300*|0x0302*|0x0380*) ;; *) continue ;; esac
    _ven="$(cat "$_d/vendor" 2>/dev/null)" || continue
    _GPU_IDS="$_GPU_IDS $_ven"
  done

  # NVIDIA takes priority on hybrid (Intel + NVIDIA) laptops
  GPU_VENDOR="none"
  case " $_GPU_IDS " in
    *" 0x10de "*) GPU_VENDOR="nvidia" ;;
    *" 0x1002 "*) GPU_VENDOR="amd"    ;;
    *" 0x8086 "*) GPU_VENDOR="intel"  ;;
  esac
  info "Detected GPU vendor: ${GPU_VENDOR}"

  # Detect an Intel iGPU independently of the primary vendor
  HAS_INTEL_IGPU=false
  case " $_GPU_IDS " in
    *" 0x8086 "*) HAS_INTEL_IGPU=true ;;
  esac
  if [[ "$GPU_VENDOR" == "nvidia" ]] && $HAS_INTEL_IGPU; then
    info "Hybrid GPU detected: Intel iGPU + NVIDIA dGPU"
  fi

  NVIDIA_BRANCH=""
  if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    _NV_NAME="$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' | grep -i nvidia | head -n1 | sed -E 's/.*: //')" || true
    if [[ -n "${_NV_NAME:-}" ]]; then echo -e "  Detected card: ${_NV_NAME}"; fi
    echo -e "${BOLD}  NVIDIA driver branch:${RESET}"
    echo "    1) Current - Turing (GTX 16 / RTX 20) and newer"
    echo "    2) Legacy 580xx - Maxwell / Pascal (GeForce 900 and 10 series)"
    while true; do
      read -rp "  Select NVIDIA branch [1/2]: " _nv_choice
      case "$_nv_choice" in
        1) NVIDIA_BRANCH="current"; break ;;
        2) NVIDIA_BRANCH="580xx";   break ;;
        *) echo "    Please enter 1 or 2." ;;
      esac
    done
  fi

  echo -e "\n${BOLD}Keyboard layout:${RESET}"
  echo "    1) International (us/intl)"
  echo "    2) ABNT (br)"
  while true; do
    read -rp "  Select keyboard layout [1/2]: " _kbd_choice
    case "$_kbd_choice" in
      1) KBD_LAYOUT="us"; KBD_VARIANT="intl"; KBD_LABEL="International"; break ;;
      2) KBD_LAYOUT="br"; KBD_VARIANT="";     KBD_LABEL="ABNT";          break ;;
      *) echo "    Please enter 1 or 2." ;;
    esac
  done

  echo -e "\n${BOLD}Logitech K380:${RESET}"
  OPT_K380=false; ask_yn "Do you own a Logitech K380 keyboard? (enable standard F keys)" && OPT_K380=true || true

  echo "  Display scale:"
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

  echo -e "\n${BOLD}Git configuration:${RESET}"
  OPT_GIT=false; ask_yn "Configure Git identity?" && OPT_GIT=true || true
  GIT_NAME=""; GIT_EMAIL=""
  if $OPT_GIT; then
    read -rp "  Full name for git: " GIT_NAME
    read -rp "  Email for git: "     GIT_EMAIL
  fi

  echo -e "\n${BOLD}LibreOffice removal:${RESET}"
  OPT_REMOVE_LIBREOFFICE=false; ask_yn "Remove LibreOffice (pre-installed)?" && OPT_REMOVE_LIBREOFFICE=true || true

  divider
  echo -e "${BOLD}  Summary - the following will be installed/configured${RESET}"
  divider
  echo -e "  Keyboard:      ${KBD_LABEL}"
  echo -e "  Logitech K380: ${OPT_K380}"
  echo -e "  Display:       scale ${EDP_SCALE}"
  echo -e "  DNF opt:       qbittorrent=${OPT_QBITTORRENT} steam=${OPT_STEAM} obs=${OPT_OBS} distrobox=${OPT_DISTROBOX} docker=${OPT_DOCKER} neovim=${OPT_NEOVIM} emacs=${OPT_EMACS} gamemode=${OPT_GAMEMODE}"
  echo -e "  Flatpak opt:   telegram=${OPT_TELEGRAM} heroic=${OPT_HEROIC} spotify=${OPT_SPOTIFY} bottles=${OPT_BOTTLES} protonplus=${OPT_PROTONPLUS} gearlever=${OPT_GEARLEVER} resources=${OPT_RESOURCES}"
  echo -e "  Graphics:      $(if [[ "$GPU_VENDOR" == "nvidia" ]]; then echo "nvidia (${NVIDIA_BRANCH})$(if $HAS_INTEL_IGPU; then echo " + intel igpu"; fi)"; else echo "$GPU_VENDOR"; fi)"
  echo -e "  Git identity:  ${OPT_GIT} $(if $OPT_GIT; then echo "${GIT_NAME} <${GIT_EMAIL}>"; fi)"
  echo -e "  Remove LibreOffice: ${OPT_REMOVE_LIBREOFFICE}"
  echo ""
  ask_yn "Proceed?" || { echo "Aborted."; exit 0; }
}

# -----------------------------------------------------------------------------
# Answers: reuse a prior run's, or collect and save them
# -----------------------------------------------------------------------------
_require_network
if [[ -f "$ANSWERS" ]]; then
  info "Restoring previous answers from a prior run"
  # shellcheck disable=SC1090
  source "$ANSWERS"
else
  collect_answers
  _atmp="$(mktemp -p "$STATE_DIR" .answers.XXXXXX)"
  save_answers "$_atmp"
  mv -f "$_atmp" "$ANSWERS"
  info "Answers saved to $ANSWERS"
fi

# =============================================================================
# Step 1 - Enable third-party software, Flathub, and RPM Fusion
# =============================================================================
if pending 1; then
step "1 - Enabling third-party software, Flathub, and RPM Fusion"

# Fetch packages in parallel
if grep -q '^max_parallel_downloads' /etc/dnf/dnf.conf; then
  warn "max_parallel_downloads already set in /etc/dnf/dnf.conf - skipping"
else
  echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf > /dev/null
  info "max_parallel_downloads=10 added to /etc/dnf/dnf.conf"
fi

# Enable Fedora's third-party repositories
if command -v fedora-third-party &>/dev/null; then
  sudo fedora-third-party enable
  info "Fedora third-party repositories enabled"
else
  warn "fedora-third-party not found; skipping (is this Fedora Workstation?)"
fi

# Ensure the Flathub remote exists (step 6 installs from it)
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
info "Flathub remote ensured"

sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
sudo dnf update -y
mark_done 1
fi

# =============================================================================
# Step 2 - Swap ffmpeg-free for ffmpeg full and install multimedia codecs
# =============================================================================
if pending 2; then
step "2 - Swapping ffmpeg-free for ffmpeg full and installing multimedia codecs"

if rpm -q ffmpeg-free &>/dev/null; then
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
else
  info "ffmpeg (full) already in place; skipping swap"
fi

sudo dnf group install -y multimedia
info "multimedia group installed (extra codecs, HEIF/HEVC, aptX)"
mark_done 2
fi

# =============================================================================
# Step 3 - Configure Logitech K380 function keys (optional)
# =============================================================================
if pending 3; then
if $OPT_K380; then
  step "3 - Configuring Logitech K380 function keys"
  _K380_TMP="$(mktemp -d -p "$TMP_ROOT")"
  curl -fsSL --retry 3 --retry-delay 2 -o "$_K380_TMP/k380.zip" \
    https://github.com/jergusg/k380-function-keys-conf/archive/refs/tags/v1.1.zip
  unzip -q "$_K380_TMP/k380.zip" -d "$_K380_TMP"
  _K380_DIR="$_K380_TMP/k380-function-keys-conf-1.1"
  chmod +x "$_K380_DIR"/*.sh 2>/dev/null || true

  ( cd "$_K380_DIR" && sudo make install && sudo make reload )
  info "k380_conf installed and udev rule registered (persists across reconnects)"

  _K380_DEV="$( { (cd "$_K380_DIR" && sudo ./fn_on.sh 2>&1 || true) | grep -oE 'hidraw[0-9]+' | head -n1; } || true )"
  if [[ -n "$_K380_DEV" ]]; then
    if sudo k380_conf -d "/dev/$_K380_DEV" -f on; then
      info "F keys enabled on /dev/$_K380_DEV"
    else
      warn "k380_conf failed; reconnect the keyboard to apply automatically"
    fi
  else
    info "K380 not connected now; F keys will be enabled automatically when it connects"
  fi

  rm -rf "$_K380_TMP"
else
  info "Skipping step 3 (Logitech K380 not requested)"
fi
mark_done 3
fi

# =============================================================================
# Step 4 - Remove unwanted pre-installed packages
# =============================================================================
if pending 4; then
step "4 - Removing unwanted pre-installed packages"

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
  gnome-classic-session \
  gnome-software || true

# Remove unwanted third-party repositories
sudo rm -f /etc/yum.repos.d/google-chrome.repo
sudo dnf copr remove -y phracek/PyCharm || true
mark_done 4
fi

# =============================================================================
# Step 5 - Install DNF packages
# =============================================================================
if pending 5; then
step "5 - Installing DNF packages"

DNF_PKGS=(
  google-noto-emoji-fonts
  google-noto-fonts-all
  pipewire-codec-aptx
  adw-gtk3-theme
  gnome-tweaks
  fastfetch
  wine-core
  fd-find
  zoxide
  kitty
  slurp
  unzip
  unrar
  7zip
  zip
  vlc
)

$OPT_GAMEMODE    && DNF_PKGS+=(gamemode mangohud)
$OPT_QBITTORRENT && DNF_PKGS+=(qbittorrent)
$OPT_OBS         && DNF_PKGS+=(obs-studio)
$OPT_DISTROBOX   && DNF_PKGS+=(distrobox)
$OPT_STEAM       && DNF_PKGS+=(steam)
$OPT_EMACS       && DNF_PKGS+=(emacs)

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

# Lower CPU/I/O priority for this large transaction so the end-of-transaction
# file triggers don't starve the graphical compositor and freeze the session
sudo nice -n 19 ionice -c 3 dnf install -y "${DNF_PKGS[@]}"
info "Base packages installed"
mark_done 5
fi

# =============================================================================
# Step 6 - Install Flatpaks
# =============================================================================
if pending 6; then
step "6 - Installing Flatpaks"

FLATPAK_PKGS=(
  page.codeberg.libre_menu_editor.LibreMenuEditor
  org.localsend.localsend_app
  io.github.kolunmi.Bazaar
)

$OPT_HEROIC     && FLATPAK_PKGS+=(com.heroicgameslauncher.hgl)
$OPT_DISTROBOX  && FLATPAK_PKGS+=(com.ranfdev.DistroShelf)
$OPT_BOTTLES    && FLATPAK_PKGS+=(com.usebottles.bottles)
$OPT_PROTONPLUS && FLATPAK_PKGS+=(com.vysp3r.ProtonPlus)
$OPT_TELEGRAM   && FLATPAK_PKGS+=(org.telegram.desktop)
$OPT_GEARLEVER  && FLATPAK_PKGS+=(it.mijorus.gearlever)
$OPT_RESOURCES  && FLATPAK_PKGS+=(net.nokyan.Resources)
$OPT_SPOTIFY    && FLATPAK_PKGS+=(com.spotify.Client)

# GPU Screen Recorder: hardware-accelerated capture
if [[ "$GPU_VENDOR" == "nvidia" || "$GPU_VENDOR" == "amd" ]]; then
  FLATPAK_PKGS+=(com.dec05eba.gpu_screen_recorder)
fi

sudo flatpak install -y flathub "${FLATPAK_PKGS[@]}"
mark_done 6
fi

# =============================================================================
# Step 7 - Configure Git (optional)
# =============================================================================
if pending 7; then
if $OPT_GIT; then
  step "7 - Configuring Git"
  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global init.defaultBranch main
  git config --global core.autocrlf input
  git config --global core.safecrlf true
  git config --global color.ui true
  info "Git configured for: ${GIT_NAME} <${GIT_EMAIL}>"
else
  info "Skipping step 7 (Git configuration not requested)"
fi
mark_done 7
fi

# =============================================================================
# Step 8 - Configure ~/.bashrc
# =============================================================================
if pending 8; then
step "8 - Configuring ~/.bashrc"

if grep -q 'export EDITOR=' ~/.bashrc; then
  warn "EDITOR/VISUAL already set in ~/.bashrc - skipping"
else
  cat >> ~/.bashrc << 'EOF'

# Default editor
export EDITOR="nvim"
export VISUAL="nvim"
EOF
  info "EDITOR/VISUAL set to nvim in ~/.bashrc"
fi

if grep -q 'mise activate bash' ~/.bashrc; then
  warn "mise block already present in ~/.bashrc - skipping"
else
  cat >> ~/.bashrc << 'EOF'

# Mise
eval "$(mise activate bash)"
EOF
  info "mise activation added to ~/.bashrc"
fi

if grep -q '_ZO_DOCTOR' ~/.bashrc; then
  warn "Zoxide block already present in ~/.bashrc - skipping"
else
  cat >> ~/.bashrc << 'EOF'

# Zoxide (keep this at the end of the file)
export _ZO_DOCTOR=0
eval "$(zoxide init bash --cmd cd)"
EOF
  info "Zoxide block added to ~/.bashrc"
fi
mark_done 8
fi

# =============================================================================
# Step 9 - Install niri and noctalia-shell
# =============================================================================
if pending 9; then
step "9 - Installing niri and noctalia-shell"

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
mark_done 9
fi

# =============================================================================
# Step 10 - Configure environment variables
# =============================================================================
if pending 10; then
step "10 - Configuring session environment variables"

if grep -q 'GSK_RENDERER=gl' /etc/environment 2>/dev/null; then
  warn "Session env block already present in /etc/environment - skipping"
else
  sudo tee -a /etc/environment > /dev/null << 'EOF'
# Keep GTK4 on the OpenGL renderer (opens Nautilus faster in niri)
GSK_RENDERER=gl
EOF
  info "Session environment variables written to /etc/environment"
fi
mark_done 10
fi

# =============================================================================
# Step 11 - Configure kitty
# =============================================================================
if pending 11; then
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
mark_done 11
fi

# =============================================================================
# Step 12 - Configure neovim (optional)
# =============================================================================
if pending 12; then
if $OPT_NEOVIM; then
  step "12 - Configuring neovim"
  sudo dnf install -y neovim
  sudo rm -r /usr/share/applications/nvim.desktop
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
mark_done 12
fi

# =============================================================================
# Step 13 - Set up assets
# =============================================================================
if pending 13; then
step "13 - Setting up directories and assets"

mkdir -p ~/Pictures
[[ -d "$ASSETS_DIR/Wallpapers" ]] && mv "$ASSETS_DIR/Wallpapers" ~/Pictures/Wallpapers
info "Wallpapers installed to ~/Pictures/Wallpapers"

# VLC config -> ~/.config/vlc
if [[ -d "$ASSETS_DIR/vlc" ]]; then
  mkdir -p ~/.config
  mv "$ASSETS_DIR/vlc" ~/.config/vlc
  info "VLC config moved to ~/.config/vlc"
fi
mark_done 13
fi

# =============================================================================
# Step 14 - Configure noctalia and niri
# =============================================================================
if pending 14; then
step "14 - Configuring noctalia and niri"

mkdir -p ~/.local/state/noctalia
[[ -f "$ASSETS_DIR/settings.toml" ]] && mv "$ASSETS_DIR/settings.toml" ~/.local/state/noctalia/
info "Noctalia settings moved to ~/.local/state/noctalia"

NIRI_SRC="$ASSETS_DIR/niri"
NIRI_DST="$HOME/.config/niri"

[[ -d "$NIRI_SRC" ]] || die "niri config folder not found at $NIRI_SRC"

mkdir -p "$HOME/.config"
rm -rf "$NIRI_DST"
mv "$NIRI_SRC" "$NIRI_DST"
info "niri config moved to $NIRI_DST"

# --- input.kdl: keyboard layout + variant ---------------------------------
sed -i -E "s|^([[:space:]]*layout[[:space:]]+)\"[^\"]*\"|\\1\"${KBD_LAYOUT}\"|" \
  "$NIRI_DST/input.kdl"

if [[ -n "$KBD_VARIANT" ]]; then
  if grep -qE '^[[:space:]]*variant[[:space:]]+"' "$NIRI_DST/input.kdl"; then
    # Variant line present: overwrite its value.
    sed -i -E "s|^([[:space:]]*variant[[:space:]]+)\"[^\"]*\"|\\1\"${KBD_VARIANT}\"|" \
      "$NIRI_DST/input.kdl"
  else
    # No variant line: insert one after layout, matching its indentation.
    sed -i -E "s|^([[:space:]]*)(layout[[:space:]]+\"[^\"]*\")|\\1\\2\\n\\1variant \"${KBD_VARIANT}\"|" \
      "$NIRI_DST/input.kdl"
  fi
else
  # ABNT (no variant): strip any variant line so a stale one can't linger.
  sed -i -E '/^[[:space:]]*variant[[:space:]]+"/d' "$NIRI_DST/input.kdl"
fi
info "input.kdl keyboard set to layout=\"${KBD_LAYOUT}\"${KBD_VARIANT:+ variant=\"${KBD_VARIANT}\"}"

# --- display.kdl: eDP-1 scale ---------------------------------------------
sed -i -E '/output "eDP-1"[[:space:]]*\{/,/\}/ s|^([[:space:]]*scale[[:space:]]+).*|\1'"${EDP_SCALE}"'|' \
  "$NIRI_DST/display.kdl"
info "display.kdl eDP-1 scale set to ${EDP_SCALE}"
mark_done 14
fi

# =============================================================================
# Step 15 - Configure MIME handling
# =============================================================================
if pending 15; then

# Ensure ~/.config/mimeapps.list exists as a file (never a directory)
[[ -d ~/.config/mimeapps.list ]] && rm -rf ~/.config/mimeapps.list
touch ~/.config/mimeapps.list
info "~/.config/mimeapps.list ensured as an empty file"
mark_done 15
fi

# =============================================================================
# Step 16 - Install and configure Numix icons + themes
# =============================================================================
if pending 16; then
step "16 - Installing Numix icons and configuring themes"

_NUMIX_TMP="$(mktemp -d -p "$TMP_ROOT")"

(
  cd "$_NUMIX_TMP"
  git clone https://github.com/numixproject/numix-icon-theme
  git clone https://github.com/numixproject/numix-icon-theme-circle
  git clone https://github.com/numixproject/numix-folders

  sudo rm -rf /usr/share/icons/Numix \
              /usr/share/icons/Numix-Light \
              /usr/share/icons/Numix-Circle \
              /usr/share/icons/Numix-Circle-Light \
              /usr/share/icons/numix-folders

  sudo mv numix-icon-theme/Numix /usr/share/icons/
  sudo mv numix-icon-theme/Numix-Light /usr/share/icons/
  sudo mv numix-icon-theme-circle/Numix-Circle /usr/share/icons/
  sudo mv numix-icon-theme-circle/Numix-Circle-Light /usr/share/icons/
  sudo mv numix-folders /usr/share/icons/
)
rm -rf "$_NUMIX_TMP"

( cd /usr/share/icons/numix-folders && printf '5\ngrey\n' | sudo ./numix-folders -t )
info "numix-folders configured (style 5, grey)"

gsettings set org.gnome.desktop.interface icon-theme "Numix-Circle"
info "Icon theme set to Numix-Circle"

gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
info "Color scheme set to prefer-dark"

gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
info "Legacy application theme set to adw-gtk3-dark"

gsettings set org.gnome.nautilus.preferences default-sort-order 'type'
info "Nautilus default sort order set to Type"

gsettings set org.gnome.desktop.privacy remember-recent-files false
rm -f ~/.local/share/recently-used.xbel
info "GNOME File History disabled and cleared"

# Unpin everything from the dash/dock
gsettings set org.gnome.shell favorite-apps "[]"
info "GNOME dock favorites cleared"

# Disable the top-left hot corner
gsettings set org.gnome.desktop.interface enable-hot-corners false
info "GNOME hot corner disabled"

# Disable drag-to-edge window snap/resize
gsettings set org.gnome.mutter edge-tiling false
info "GNOME edge-tiling (drag-to-edge resize) disabled"

# Wallpaper
_WALL="$HOME/Pictures/Wallpapers/01.jpg"
if [[ -f "$_WALL" ]]; then
  gsettings set org.gnome.desktop.background picture-uri "file://$_WALL"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$_WALL"
  gsettings set org.gnome.desktop.background picture-options "zoom"
  info "GNOME wallpaper set to $_WALL"
else
  warn "$_WALL not found - skipping GNOME wallpaper"
fi
mark_done 16
fi

# =============================================================================
# Step 17 - Install Docker (optional)
# =============================================================================
if pending 17; then
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
  sudo usermod -aG docker "$TARGET_USER"
  info "Docker installed, service enabled and started"
  info "User '$TARGET_USER' added to the docker group (takes effect after next login)"
else
  info "Skipping step 17 (Docker not requested)"
fi
mark_done 17
fi

# =============================================================================
# Step 18 - Kernel tuning (sysctl)
# =============================================================================
if pending 18; then
step "18 - Applying kernel tuning"
sudo tee /etc/sysctl.d/99-local-tuning.conf > /dev/null << 'EOF'
# Split-lock mitigation stalls the whole machine when an app triggers it.
kernel.split_lock_mitigate=0

# Allow SysRq. When a driver wedges the session, Alt+SysRq+REISUB syncs
# the disks and reboots cleanly instead of forcing a power cut.
kernel.sysrq=1

# File watchers: LSP servers, Emacs and build tools run out of the stock
# limits on large trees.
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
EOF
sudo sysctl -p /etc/sysctl.d/99-local-tuning.conf > /dev/null
# Drop the file the old split-lock-only step used to write, so the values are
# not defined twice.
sudo rm -f /etc/sysctl.d/99-splitlock.conf
info "Kernel tuning applied (/etc/sysctl.d/99-local-tuning.conf)"
mark_done 18
fi

# =============================================================================
# Step 19 - Bluetooth game controller compatibility
# =============================================================================
if pending 19; then
step "19 - Applying Bluetooth game controller fixes"

sudo mkdir -p /etc/bluetooth
sudo tee /etc/bluetooth/input.conf > /dev/null << 'EOF'
[General]
UserspaceHID=false
ClassicBondedOnly=false
EOF

for _kv in "ControllerMode=dual" "Privacy=device" "FastConnectable=true" \
           "JustWorksRepairing=confirm" "AlwaysPairable=true"; do
  _key="${_kv%%=*}"; _val="${_kv#*=}"
  if sudo grep -qE "^[#[:space:]]*${_key}[[:space:]]*=" /etc/bluetooth/main.conf 2>/dev/null; then
    sudo sed -i -E "s|^[#[:space:]]*${_key}[[:space:]]*=.*|${_key} = ${_val}|" /etc/bluetooth/main.conf
  else
    sudo sed -i "0,/^\[General\]/s//[General]\n${_key} = ${_val}/" /etc/bluetooth/main.conf
  fi
done

echo 'options bluetooth disable_ertm=1' | sudo tee /etc/modprobe.d/bluetooth.conf > /dev/null

# Keep Bluetooth headsets on A2DP
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
sudo tee /etc/wireplumber/wireplumber.conf.d/51-no-headset-autoswitch.conf > /dev/null << 'EOF'
wireplumber.settings = {
  bluetooth.autoswitch-to-headset-profile = false
}
EOF

sudo systemctl restart bluetooth
systemctl --user restart wireplumber 2>/dev/null || true
info "Bluetooth fixes applied (input.conf, main.conf, ERTM off, A2DP kept)"
mark_done 19
fi

# =============================================================================
# Step 20 - Disable audio device auto-suspend (WirePlumber)
# =============================================================================
if pending 20; then
step "20 - Disabling audio device auto-suspend"
# Stop WirePlumber from suspending idle ALSA nodes. Auto-suspend is what causes
# the audible pop/click and the clipped first ~200ms when a sink/source wakes
# (common on DACs, HDMI audio, and many onboard codecs).
sudo mkdir -p /etc/wireplumber/wireplumber.conf.d
sudo tee /etc/wireplumber/wireplumber.conf.d/51-disable-suspension.conf > /dev/null << 'EOF'
monitor.alsa.rules = [
  {
    matches = [
      {
        # Matches all sources
        node.name = "~alsa_input.*"
      },
      {
        # Matches all sinks
        node.name = "~alsa_output.*"
      }
    ]
    actions = {
      update-props = {
        session.suspend-timeout-seconds = 0
      }
    }
  }
]
EOF
# Apply now if a user WirePlumber is running; otherwise it takes effect at login.
systemctl --user restart wireplumber 2>/dev/null || true
info "Audio auto-suspend disabled (/etc/wireplumber/wireplumber.conf.d/51-disable-suspension.conf)"
mark_done 20
fi

# =============================================================================
# Step 21 - Install graphics drivers
# =============================================================================
if pending 21; then
if [[ "$GPU_VENDOR" == "nvidia" ]]; then
  step "21 - Installing NVIDIA drivers (${NVIDIA_BRANCH}) and enabling Wayland support"

  case "$NVIDIA_BRANCH" in
    current) sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs.i686 ;;
    580xx)   sudo dnf install -y akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx-cuda ;;
  esac

  # Enable DRM kernel mode setting (required for Wayland)
  echo 'options nvidia_drm modeset=1 fbdev=1' | sudo tee /etc/modprobe.d/nvidia-drm-modeset.conf > /dev/null

  # TemporaryFilePath  - where VRAM is dumped on suspend. The default is /tmp,
  #                      which is tmpfs on Fedora: several GB of VRAM would be
  #                      written into RAM. /var/tmp is real storage.
  # PageAttributeTable - lets the driver use PAT for memory mapping instead of
  #                      the slower MTRR path.
  sudo tee /etc/modprobe.d/nvidia-local.conf > /dev/null << 'EOF'
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_UsePageAttributeTable=1
EOF

  # Early-load from the initramfs, NOT via /etc/modules-load.d
  # Verify with: sudo ausearch -m avc -c nv_queue -ts boot # expected: no matches
  sudo tee /etc/dracut.conf.d/nvidia.conf > /dev/null << 'EOF'
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
EOF
  # Drop any stale modules-load.d file from an older run of this script so the
  # modules are not also loaded the AVC-triggering way.
  sudo rm -f /etc/modules-load.d/nvidia.conf

  sudo akmods --force
  sudo dracut --force

  # Redundant with the modprobe.d drop-in above, but kept as a safety net: if an
  # update ever regenerates the initramfs without it, the modeset is lost.
  if ! grep -q 'nvidia-drm.modeset=1' /proc/cmdline; then
    sudo grubby --update-kernel=ALL --args='nvidia-drm.modeset=1'
    info "nvidia-drm.modeset=1 added to the kernel command line (grubby)"
  else
    info "nvidia-drm.modeset=1 already on the kernel command line - skipping"
  fi

  # Without these the GPU state is not saved/restored across suspend and
  # hibernate, which shows up as corruption or a hang on resume.
  for _svc in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service nvidia-powerd.service; do
    if systemctl cat "$_svc" &>/dev/null; then
      sudo systemctl enable "$_svc" &>/dev/null && info "$_svc enabled" || warn "Could not enable $_svc"
    else
      warn "$_svc not found - skipping"
    fi
  done

  if grep -q '__GL_SHADER_DISK_CACHE_SKIP_CLEANUP' /etc/environment 2>/dev/null; then
    warn "NVIDIA environment block already present in /etc/environment - skipping"
  else
    # Shader cache + Proton tweaks
    sudo tee -a /etc/environment > /dev/null << 'EOF'
# Nvidia shader cache: 12GB size + skip cleanup on launch (prevents stutter spikes)
__GL_SHADER_DISK_CACHE_SIZE=12000000000
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
# Fixes Steam stuttering after 25-30+ minutes of play
LD_PRELOAD=""
EOF
    # Proton features make sense only on the current (Turing+) branch
    if [[ "$NVIDIA_BRANCH" == "current" ]]; then
      sudo tee -a /etc/environment > /dev/null << 'EOF'
# Force Proton to use native Wayland rendering path
PROTON_ENABLE_WAYLAND=1
# Enables NVAPI for features like DLSS in Proton
PROTON_ENABLE_NVAPI=1
EOF
    fi
    info "NVIDIA environment variables written to /etc/environment"
  fi

  # Video decode: on a hybrid laptop, route VA-API through the Intel iGPU.
  if $HAS_INTEL_IGPU; then
    sudo dnf install -y intel-media-driver
    if grep -q 'LIBVA_DRIVER_NAME' /etc/environment 2>/dev/null; then
      warn "LIBVA_DRIVER_NAME already present in /etc/environment - skipping"
    else
      echo 'LIBVA_DRIVER_NAME=iHD' | sudo tee -a /etc/environment > /dev/null
      info "Hybrid: video decode routed to Intel iGPU (LIBVA_DRIVER_NAME=iHD)"
    fi
  else
    sudo dnf install -y libva-nvidia-driver
    if grep -q 'LIBVA_DRIVER_NAME' /etc/environment 2>/dev/null; then
      warn "LIBVA_DRIVER_NAME already present in /etc/environment - skipping"
    else
      echo 'LIBVA_DRIVER_NAME=nvidia' | sudo tee -a /etc/environment > /dev/null
      info "NVIDIA-only: VA-API bridged to NVDEC (libva-nvidia-driver, LIBVA_DRIVER_NAME=nvidia)"
    fi
  fi

  # If the GPU resets, kill the process that caused it; if VRAM was lost, restart
  # the display manager. Turns a full lockup into a session restart.
  sudo tee /etc/udev/rules.d/80-gpu-reset.rules > /dev/null << 'EOF'
# If a GPU crash is caused by a specific process, kill the PID
ACTION=="change", ENV{DEVNAME}=="/dev/dri/card0", ENV{RESET}=="1", ENV{PID}!="0", RUN+="/sbin/kill -9 %E{PID}"

# Restart the display manager if the GPU crashes and VRAM is lost
ACTION=="change", ENV{DEVNAME}=="/dev/dri/card0", ENV{RESET}=="1", ENV{FLAGS}=="1", RUN+="/usr/sbin/systemctl restart gdm"
EOF
  sudo udevadm control --reload-rules 2>/dev/null || true
  info "GPU reset recovery rule written to /etc/udev/rules.d/80-gpu-reset.rules"

  # niri-specific: cap the NVIDIA free buffer pool so VRAM usage stays low
  # (https://niri-wm.github.io/niri/Nvidia.html#high-vram-usage-fix)
  sudo mkdir -p /etc/nvidia/nvidia-application-profiles-rc.d
  sudo tee /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json > /dev/null << 'EOF'
{
    "rules": [
        {
            "pattern": {
                "feature": "procname",
                "matches": "niri"
            },
            "profile": "Limit Free Buffer Pool On Wayland Compositors"
        }
    ],
    "profiles": [
        {
            "name": "Limit Free Buffer Pool On Wayland Compositors",
            "settings": [
                {
                    "key": "GLVidHeapReuseRatio",
                    "value": 0
                }
            ]
        }
    ]
}
EOF
  info "NVIDIA application profile written to keep niri VRAM usage low"

  info "NVIDIA drivers take effect after the final reboot - verify then with: nvidia-smi"

elif [[ "$GPU_VENDOR" == "intel" ]]; then
  step "21 - Installing Intel media driver (VAAPI)"
  sudo dnf install -y intel-media-driver

  if grep -q 'LIBVA_DRIVER_NAME' /etc/environment 2>/dev/null; then
    warn "LIBVA_DRIVER_NAME already present in /etc/environment - skipping"
  else
    echo 'LIBVA_DRIVER_NAME=iHD' | sudo tee -a /etc/environment > /dev/null
    info "LIBVA_DRIVER_NAME=iHD written to /etc/environment"
  fi

elif [[ "$GPU_VENDOR" == "amd" ]]; then
  step "21 - Configuring AMD graphics (Mesa + VA-API)"
  if rpm -q mesa-va-drivers-freeworld > /dev/null 2>&1; then
    warn "mesa-va-drivers-freeworld already installed - skipping VA swap"
  else
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
  fi
  if rpm -q mesa-vdpau-drivers-freeworld > /dev/null 2>&1; then
    warn "mesa-vdpau-drivers-freeworld already installed - skipping VDPAU swap"
  else
    sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
  fi
  info "AMD: amdgpu + Mesa in use; VA/VDPAU drivers swapped to freeworld for full hardware video decode"

else
  info "Skipping step 21 (no supported GPU detected)"
fi
mark_done 21
fi

# =============================================================================
# Step 22 - System update and cleanup
# =============================================================================
if pending 22; then
step "22 - System update and cleanup"
sudo dnf upgrade -y
sudo dnf remove -y rygel firefox
sudo dnf clean all
sudo dnf autoremove -y
mark_done 22
fi

# =============================================================================
# Done
# =============================================================================
divider
echo -e "${BOLD}${GREEN}  Setup complete${RESET}"
divider
echo ""

rm -rf "$STATE_DIR"

if $OPT_GIT; then
  echo -e "${BOLD}  Git / SSH:${RESET}"
  echo -e "  Git was configured for: ${GIT_NAME} <${GIT_EMAIL}>"
  echo -e "  To create an SSH key, run:"
  echo -e "    ${CYAN}ssh-keygen -t ed25519 -C \"${GIT_EMAIL}\"${RESET}"
  echo ""
fi
info "Log out and pick the niri session to start using it."
ask_yn "Reboot now?" && sudo reboot || echo -e "\n  Reboot skipped. Remember to reboot before starting niri."
