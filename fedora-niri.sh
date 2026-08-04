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
    SHELL_CHOICE GPU_VENDOR HAS_INTEL_IGPU NVIDIA_BRANCH TARGET_USER > "$1"
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

  # --- Display ---
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
  echo -e "${BOLD}  Summary - the following will be installed/configured${RESET}"
  divider
  echo -e "  Keyboard:      ${KBD_LABEL}"
  echo -e "  Logitech K380: ${OPT_K380}"
  echo -e "  Display:       scale ${EDP_SCALE}"
  echo -e "  DNF opt:       qbittorrent=${OPT_QBITTORRENT} steam=${OPT_STEAM} obs=${OPT_OBS} distrobox=${OPT_DISTROBOX} docker=${OPT_DOCKER} neovim=${OPT_NEOVIM} emacs=${OPT_EMACS} gamemode=${OPT_GAMEMODE}"
  echo -e "  Flatpak opt:   telegram=${OPT_TELEGRAM} heroic=${OPT_HEROIC} spotify=${OPT_SPOTIFY} bottles=${OPT_BOTTLES} protonplus=${OPT_PROTONPLUS} gearlever=${OPT_GEARLEVER} resources=${OPT_RESOURCES}"
  echo -e "  Video player:  vlc (flatpak)"
  echo -e "  Graphics:      $(if [[ "$GPU_VENDOR" == "nvidia" ]]; then echo "nvidia (${NVIDIA_BRANCH})$(if $HAS_INTEL_IGPU; then echo " + intel igpu"; fi)"; else echo "$GPU_VENDOR"; fi)"
  echo -e "  Shell:         ${SHELL_CHOICE}"
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

# Ensure the Flathub remote exists (step 5 installs from it)
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
# Step 3 - Remove unwanted pre-installed packages
# =============================================================================
if pending 3; then
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
  gnome-classic-session \
  gnome-software || true

# Remove unwanted third-party repositories
sudo rm -f /etc/yum.repos.d/google-chrome.repo
sudo dnf copr remove -y phracek/PyCharm || true
mark_done 3
fi

# =============================================================================
# Step 4 - Install DNF packages
# =============================================================================
if pending 4; then
step "4 - Installing DNF packages"

DNF_PKGS=(
  google-noto-emoji-fonts
  google-noto-fonts-all
  pipewire-codec-aptx
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

sudo dnf install -y pipx
pipx ensurepath
info "Base packages and pipx installed"
mark_done 4
fi

# =============================================================================
# Step 5 - Install Flatpaks
# =============================================================================
if pending 5; then
step "5 - Installing Flatpaks"

FLATPAK_PKGS=(
  page.codeberg.libre_menu_editor.LibreMenuEditor
  org.localsend.localsend_app
  io.github.kolunmi.Bazaar
  org.videolan.VLC
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
mark_done 5
fi

# =============================================================================
# Step 6 - Configure Git (optional)
# =============================================================================
if pending 6; then
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
mark_done 6
fi

# =============================================================================
# Step 7 - Configure shell
# =============================================================================
if pending 7; then
if [[ "$SHELL_CHOICE" == "bash" ]]; then
  step "7 - Configuring ~/.bashrc"

  if grep -q '_ZO_DOCTOR' ~/.bashrc; then
    warn "Zoxide block already present in ~/.bashrc - skipping"
  else
    cat >> ~/.bashrc << 'EOF'

# Zoxide
export _ZO_DOCTOR=0
eval "$(zoxide init bash --cmd cd)"
EOF
    info "Zoxide block added to ~/.bashrc"
  fi

  if grep -q 'mise activate bash' ~/.bashrc; then
    warn "mise block already present in ~/.bashrc - skipping"
  else
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
    info "mise activation added to ~/.bashrc"
  fi
else
  step "7 - Installing and configuring fish shell"
  sudo dnf install -y fish
  _FISH_BIN="$(command -v fish)"
  if ! grep -qxF "$_FISH_BIN" /etc/shells; then
    echo "$_FISH_BIN" | sudo tee -a /etc/shells > /dev/null
  fi
  sudo chsh -s "$_FISH_BIN" "$TARGET_USER"
  mkdir -p ~/.config/fish
  cat > ~/.config/fish/config.fish << 'EOF'
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
mark_done 7
fi

# =============================================================================
# Step 8 - Install niri and noctalia-shell
# =============================================================================
if pending 8; then
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
mark_done 8
fi

# =============================================================================
# Step 9 - Configure environment variables
# =============================================================================
if pending 9; then
step "9 - Configuring session environment variables"

if grep -q 'GSK_RENDERER=gl' /etc/environment 2>/dev/null; then
  warn "Session env block already present in /etc/environment - skipping"
else
  sudo tee -a /etc/environment > /dev/null << 'EOF'
# Keep GTK4 on the OpenGL renderer (opens Nautilus faster in niri)
GSK_RENDERER=gl

# Toolkit variables (Qt/Electron/GTK) live in the niri config's environment
# block instead, so they only apply inside the graphical session.
EOF
  info "Session environment variables written to /etc/environment"
fi
mark_done 9
fi

# =============================================================================
# Step 10 - Configure kitty
# =============================================================================
if pending 10; then
step "10 - Configuring kitty"
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
mark_done 10
fi

# =============================================================================
# Step 11 - Configure neovim (optional)
# =============================================================================
if pending 11; then
if $OPT_NEOVIM; then
  step "11 - Configuring neovim"
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
  info "Skipping step 11 (neovim not requested)"
fi
mark_done 11
fi

# =============================================================================
# Step 12 - Install wallpapers
# =============================================================================
if pending 12; then
step "12 - Installing wallpapers"

mkdir -p ~/Pictures
[[ -d ~/fedora-niri/Wallpapers ]] && mv ~/fedora-niri/Wallpapers ~/Pictures/Wallpapers
info "Wallpapers installed to ~/Pictures/Wallpapers"
mark_done 12
fi

# =============================================================================
# Step 13 - Configure noctalia and niri
# =============================================================================
if pending 13; then
step "13 - Configuring noctalia and niri"

mkdir -p ~/.local/state/noctalia
[[ -f ~/fedora-niri/settings.toml ]] && mv ~/fedora-niri/settings.toml ~/.local/state/noctalia/
info "Noctalia settings moved to ~/.local/state/noctalia"

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

environment {
  QT_QPA_PLATFORM "wayland"
  QT_QPA_PLATFORMTHEME "gtk3"
  QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
  ELECTRON_OZONE_PLATFORM_HINT "auto"
}

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
  match app-id=r#"zen$"# title="^Picture-in-Picture$"
  open-floating true
}

binds {
  Mod+Shift+Slash { show-hotkey-overlay; }

  Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
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
mark_done 13
fi

# =============================================================================
# Step 14 - Configure MIME handling
# =============================================================================
if pending 14; then

# Ensure ~/.config/mimeapps.list exists as a file (never a directory)
[[ -d ~/.config/mimeapps.list ]] && rm -rf ~/.config/mimeapps.list
touch ~/.config/mimeapps.list
info "~/.config/mimeapps.list ensured as an empty file"
mark_done 14
fi

# =============================================================================
# Step 15 - Install and configure Numix icons + themes
# =============================================================================
if pending 15; then
step "15 - Installing Numix icons and configuring themes"

_NUMIX_TMP="$(mktemp -d -p "$TMP_ROOT")"

# Clone and install inside a subshell so the cwd change never leaks out.
(
  cd "$_NUMIX_TMP"
  git clone https://github.com/numixproject/numix-icon-theme
  git clone https://github.com/numixproject/numix-icon-theme-circle
  git clone https://github.com/numixproject/numix-folders

  # Remove any prior copies first so a re-run after a partial failure lands the
  # themes cleanly instead of nesting them (e.g. /usr/share/icons/Numix/Numix).
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
mark_done 15
fi

# =============================================================================
# Step 16 - Install Docker (optional)
# =============================================================================
if pending 16; then
if $OPT_DOCKER; then
  step "16 - Installing Docker"
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
  info "Skipping step 16 (Docker not requested)"
fi
mark_done 16
fi

# =============================================================================
# Step 17 - Kernel tuning (sysctl)
# =============================================================================
if pending 17; then
step "17 - Applying kernel tuning"
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
mark_done 17
fi

# =============================================================================
# Step 17b - Disable audio device auto-suspend (WirePlumber)
# =============================================================================
if pending 17b; then
step "17b - Disabling audio device auto-suspend"
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
mark_done 17b
fi

# =============================================================================
# Step 18 - Install graphics drivers
# =============================================================================
if pending 18; then
if [[ "$GPU_VENDOR" == "nvidia" ]]; then
  step "18 - Installing NVIDIA drivers (${NVIDIA_BRANCH}) and enabling Wayland support"

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
  for _svc in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
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
# Nvidia shader cache: skip cleanup on launch (prevents stutter spikes)
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
  step "18 - Installing Intel media driver (VAAPI)"
  sudo dnf install -y intel-media-driver

  if grep -q 'LIBVA_DRIVER_NAME' /etc/environment 2>/dev/null; then
    warn "LIBVA_DRIVER_NAME already present in /etc/environment - skipping"
  else
    echo 'LIBVA_DRIVER_NAME=iHD' | sudo tee -a /etc/environment > /dev/null
    info "LIBVA_DRIVER_NAME=iHD written to /etc/environment"
  fi

elif [[ "$GPU_VENDOR" == "amd" ]]; then
  step "18 - Configuring AMD graphics (Mesa + VA-API)"
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
  info "Skipping step 18 (no supported GPU detected)"
fi
mark_done 18
fi

# =============================================================================
# Step 19 - Configure Logitech K380 function keys (optional)
# =============================================================================
if pending 19; then
if $OPT_K380; then
  step "19 - Configuring Logitech K380 function keys"
  _K380_TMP="$(mktemp -d -p "$TMP_ROOT")"
  curl -fsSL --retry 3 --retry-delay 2 -o "$_K380_TMP/k380.zip" \
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
  info "Skipping step 19 (Logitech K380 not requested)"
fi
mark_done 19
fi

# =============================================================================
# Step 20 - System update and cleanup
# =============================================================================
if pending 20; then
step "20 - System update and cleanup"
sudo dnf upgrade -y
sudo dnf remove -y rygel firefox
sudo dnf clean all
sudo dnf autoremove -y
mark_done 20
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
