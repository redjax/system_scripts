#!/usr/bin/env bash
set -euo pipefail

##########################################################################
# Install Yazi's dependencies                                            #
#                                                                        #
# The package names are intentionally distro-specific because several of #
# these tools have different names across distributions.                 #
##########################################################################

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script currently supports Linux only."
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

if [[ ! -f /etc/os-release ]]; then
  echo "ERROR: /etc/os-release not found; cannot determine Linux distribution."
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

DISTRO="${ID:-unknown}"
ID_LIKE="${ID_LIKE:-}"

echo "Detected distribution: ${PRETTY_NAME:-$DISTRO}"
echo

function install_debian() {
  $SUDO apt-get update

  $SUDO apt-get install -y \
    file \
    ffmpeg \
    jq \
    poppler-utils \
    fd-find \
    ripgrep \
    fzf \
    zoxide \
    imagemagick \
    rsync \
    unzip \
    curl \
    ca-certificates \
    fontconfig

  ## Debian/Ubuntu call the fd executable "fdfind".
  #  Create a user-local "fd" wrapper if the real fd command doesn't exist.
  if ! command -v fd > /dev/null 2>&1 && command -v fdfind > /dev/null 2>&1; then
    mkdir -p "${HOME}/.local/bin"

    cat > "${HOME}/.local/bin/fd" << 'EOF'
#!/usr/bin/env bash
exec fdfind "$@"
EOF

    chmod +x "${HOME}/.local/bin/fd"

    echo
    echo "Installed Debian's fdfind and created:"
    echo "  ${HOME}/.local/bin/fd"
    echo

    case ":${PATH}:" in
      *":${HOME}/.local/bin:"*) ;;
      *)
        echo "WARNING: ${HOME}/.local/bin is not currently in PATH."
        echo "Add it to your shell PATH if necessary."
        ;;
    esac
  fi

  ## Debian's package is normally p7zip-full, but package availability
  #  differs between Debian releases and Ubuntu releases.
  if apt-cache show p7zip-full > /dev/null 2>&1; then
    $SUDO apt-get install -y p7zip-full
  elif apt-cache show 7zip > /dev/null 2>&1; then
    $SUDO apt-get install -y 7zip
  else
    echo "WARNING: Could not find a 7-Zip package in configured repositories."
  fi
}

function install_fedora() {
  $SUDO dnf install -y \
    file \
    ffmpeg \
    jq \
    poppler-utils \
    fd-find \
    ripgrep \
    fzf \
    zoxide \
    ImageMagick \
    rsync \
    unzip \
    curl \
    ca-certificates \
    fontconfig

  ## Package name varies by Fedora/RHEL-family release.
  if $SUDO dnf install -y 7zip 2> /dev/null; then
    :
  elif $SUDO dnf install -y p7zip p7zip-plugins 2> /dev/null; then
    :
  else
    echo "WARNING: Could not install 7-Zip."
  fi
}

function install_arch() {
  $SUDO pacman -Syu --needed --noconfirm \
    file \
    ffmpeg \
    7zip \
    jq \
    poppler \
    fd \
    ripgrep \
    fzf \
    zoxide \
    resvg \
    imagemagick \
    rsync \
    unzip \
    curl \
    ca-certificates \
    fontconfig
}

function install_opensuse() {
  $SUDO zypper --non-interactive refresh

  $SUDO zypper --non-interactive install \
    file \
    ffmpeg \
    jq \
    poppler-tools \
    fd \
    ripgrep \
    fzf \
    zoxide \
    ImageMagick \
    rsync \
    unzip \
    curl \
    ca-certificates \
    fontconfig

  ## Prefer 7zz/7zip if available.
  if $SUDO zypper --non-interactive install 7zip; then
    :
  elif $SUDO zypper --non-interactive install p7zip; then
    :
  else
    echo "WARNING: Could not install 7-Zip."
  fi
}

function install_clipboard() {
  echo
  echo "Checking clipboard support"

  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    echo "Wayland detected."

    case "$DISTRO" in
      debian | ubuntu | linuxmint | pop)
        $SUDO apt-get install -y wl-clipboard
        ;;
      fedora | rhel | centos | rocky | almalinux)
        $SUDO dnf install -y wl-clipboard
        ;;
      arch)
        $SUDO pacman -S --needed --noconfirm wl-clipboard
        ;;
      opensuse* | suse)
        $SUDO zypper --non-interactive install wl-clipboard
        ;;
      void)
        $SUDO xbps-install -y wl-clipboard
        ;;
      *)
        echo "WARNING: Unknown distro; install wl-clipboard manually."
        ;;
    esac

  elif [[ -n "${DISPLAY:-}" ]]; then
    echo "X11 detected."

    case "$DISTRO" in
      debian | ubuntu | linuxmint | pop)
        $SUDO apt-get install -y xclip
        ;;
      fedora | rhel | centos | rocky | almalinux)
        $SUDO dnf install -y xclip
        ;;
      arch)
        $SUDO pacman -S --needed --noconfirm xclip
        ;;
      opensuse* | suse)
        $SUDO zypper --non-interactive install xclip
        ;;
      void)
        $SUDO xbps-install -y xclip
        ;;
      *)
        echo "WARNING: Unknown distro; install xclip/xsel manually."
        ;;
    esac

  else
    echo "No X11 or Wayland session detected."
    echo "Skipping clipboard integration."
  fi
}

case "$DISTRO" in
  debian | ubuntu | linuxmint | pop)
    install_debian
    ;;
  fedora | rhel | centos | rocky | almalinux)
    install_fedora
    ;;
  arch)
    install_arch
    ;;
  opensuse* | suse)
    install_opensuse
    ;;
  void)
    install_void
    ;;
  nixos)
    install_nix
    ;;
  *)
    if [[ "$ID_LIKE" == *debian* ]]; then
      install_debian
    elif [[ "$ID_LIKE" == *rhel* || "$ID_LIKE" == *fedora* ]]; then
      install_fedora
    else
      echo "WARNING: Unsupported distribution: $DISTRO"
      echo "Install Yazi's optional dependencies manually."
    fi
    ;;
esac

install_clipboard

echo
echo "Yazi external dependencies installed."
echo
echo "Required by Yazi:"
echo "  file"
echo
echo "Optional integrations:"
echo "  ffmpeg  7zip  jq  poppler  fd  ripgrep  fzf"
echo "  zoxide  resvg  ImageMagick  clipboard tools"
echo
