#!/usr/bin/env bash
set -euo pipefail

############################################################################################
# Installs Yazi using the best available method:                                           #
#                                                                                          #
#   Arch                  -> pacman                                                        #
#   Fedora/RHEL/Alma/etc. -> Yazi COPR + dnf                                               #
#   openSUSE              -> configured zypper repositories                                #
#   other Linux           -> official Yazi Musl binary where available                     #
#   ARMv7/unsupported     -> build from source                                             #
#                                                                                          #
# For binary installations, a systemd timer automatically checks for                       #
# upstream Yazi releases and updates the installation.                                     #
#                                                                                          #
# Usage:                                                                                   #
#                                                                                          #
#   ./install-yazi.sh [--flatpak]                                                          #
#                                                                                          #
#   Flatpak is intentionally opt-in, Yazi's documentation warns about sandbox limitations. #
############################################################################################

## Defaults
YAZI_REPO="sxyazi/yazi"
INSTALL_ROOT="/usr/local/lib/yazi"
BIN_DIR="/usr/local/bin"
UPDATE_SCRIPT="/usr/local/sbin/yazi-update"
SYSTEMD_SERVICE="/etc/systemd/system/yazi-update.service"
SYSTEMD_TIMER="/etc/systemd/system/yazi-update.timer"

USE_FLATPAK=0

## Parse args
for arg in "$@"; do
  case "$arg" in
    --flatpak)
      USE_FLATPAK=1
      ;;
    --help | -h)
      cat << 'EOF'
Usage: install-yazi.sh [--flatpak]

Options:
  --flatpak    Install the community Flatpak package instead of the
               normal native/binary installation.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

## Detect OS type
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: This installer currently supports Linux only."
  exit 1
fi

## Populate $SUDO only if not running as root
if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

## Detect Linux distribution
if [[ ! -f /etc/os-release ]]; then
  echo "ERROR: /etc/os-release not found."
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release

DISTRO="${ID:-unknown}"
ID_LIKE="${ID_LIKE:-}"
ARCH="$(uname -m)"

echo "Distribution : ${PRETTY_NAME:-$DISTRO}"
echo "Architecture : $ARCH"
echo

#############
# Functions #
#############

function require_command() {
  if ! command -v "$1" > /dev/null 2>&1; then
    echo "ERROR: Required command not found: $1"
    exit 1
  fi
}

function install_native_arch() {
  echo "Installing Yazi from Arch Linux repositories"

  $SUDO pacman -S --needed --noconfirm yazi

  disable_binary_updater

  verify_yazi
}

function install_native_dnf() {
  echo "Checking for a Yazi package in configured DNF repositories"

  if $SUDO dnf --assumeyes --quiet info yazi > /dev/null 2>&1; then
    echo "Yazi is available from the configured repositories."
  else
    echo "Yazi is not currently available."
    echo "Enabling the Yazi COPR repository"

    if ! $SUDO dnf --quiet copr enable -y lihaohong/yazi; then
      echo "dnf copr plugin unavailable; installing dnf-plugins-core"
      $SUDO dnf install -y dnf-plugins-core
      $SUDO dnf copr enable -y lihaohong/yazi
    fi
  fi

  $SUDO dnf install -y yazi

  disable_binary_updater

  verify_yazi
}

function install_native_opensuse() {
  echo "Checking configured openSUSE repositories for Yazi"

  if $SUDO zypper --non-interactive --quiet info yazi > /dev/null 2>&1; then
    echo "Yazi is available from the configured repositories."
    $SUDO zypper --non-interactive install yazi
    disable_binary_updater
    verify_yazi
    return 0
  fi

  echo "Yazi is not available from the configured repositories."
  echo "Falling back to the official Yazi Musl binary."

  install_musl
}

function install_flatpak() {
  require_command flatpak

  echo "Installing Yazi from Flathub"
  flatpak install -y flathub io.github.sxyazi.yazi

  # Flatpak exposes the application through flatpak rather than a normal
  # yazi binary. Create a small wrapper so normal shell usage still works.
  mkdir -p "${HOME}/.local/bin"

  cat > "${HOME}/.local/bin/yazi" << 'EOF'
#!/usr/bin/env bash
exec flatpak run io.github.sxyazi.yazi "$@"
EOF

  chmod +x "${HOME}/.local/bin/yazi"

  cat > "${HOME}/.local/bin/ya" << 'EOF'
#!/usr/bin/env bash
exec flatpak run io.github.sxyazi.yazi "$@"
EOF

  chmod +x "${HOME}/.local/bin/ya"

  echo
  echo "Flatpak Yazi installed."
  echo "Make sure ${HOME}/.local/bin is in PATH."
}

function github_latest_version() {
  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${YAZI_REPO}/releases/latest" |
    jq -r '.tag_name'
}

function install_musl() {
  require_command curl
  require_command jq
  require_command unzip
  require_command sha256sum

  case "$ARCH" in
    x86_64)
      YAZI_ARCH="x86_64"
      ;;
    aarch64 | arm64)
      YAZI_ARCH="aarch64"
      ;;
    *)
      echo "No official Yazi Musl binary for architecture: $ARCH"
      echo "Falling back to source build."
      install_from_source
      return 0
      ;;
  esac

  VERSION="$(github_latest_version)"

  if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    echo "ERROR: Could not determine latest Yazi release."
    exit 1
  fi

  ASSET="yazi-${YAZI_ARCH}-unknown-linux-musl.zip"

  echo "Latest Yazi release: $VERSION"
  echo "Binary: $ASSET"

  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' RETURN

  URL="https://github.com/${YAZI_REPO}/releases/download/${VERSION}/${ASSET}"

  echo "Downloading $URL"

  curl -fL \
    --retry 5 \
    --retry-delay 2 \
    --retry-connrefused \
    -o "${TMPDIR}/${ASSET}" \
    "$URL"

  echo "Retrieving release metadata"

  API_JSON="${TMPDIR}/release.json"

  curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${YAZI_REPO}/releases/tags/${VERSION}" \
    -o "$API_JSON"

  EXPECTED_SHA="$(
    jq -r --arg asset "$ASSET" '
            .assets[]
            | select(.name == $asset)
            | .digest
            | sub("^sha256:"; "")
        ' "$API_JSON"
  )"

  if [[ -z "$EXPECTED_SHA" || "$EXPECTED_SHA" == "null" ]]; then
    echo "ERROR: Could not obtain SHA-256 digest for $ASSET."
    exit 1
  fi

  ACTUAL_SHA="$(sha256sum "${TMPDIR}/${ASSET}" | awk '{print $1}')"

  if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    echo "ERROR: SHA-256 verification failed."
    echo
    echo "Expected: $EXPECTED_SHA"
    echo "Actual:   $ACTUAL_SHA"
    exit 1
  fi

  echo "SHA-256 verified."

  unzip -q "$TMPDIR/$ASSET" -d "$TMPDIR/extracted"

  YAZI_BIN="$(find "$TMPDIR/extracted" -type f -name yazi -print -quit)"
  YA_BIN="$(find "$TMPDIR/extracted" -type f -name ya -print -quit)"

  if [[ -z "$YAZI_BIN" || -z "$YA_BIN" ]]; then
    echo "ERROR: Yazi binaries were not found in archive."
    exit 1
  fi

  chmod +x "$YAZI_BIN" "$YA_BIN"

  # Validate the binaries before installing them.
  "$YAZI_BIN" --version
  "$YA_BIN" --version

  echo
  echo "Installing Yazi $VERSION to $INSTALL_ROOT"

  $SUDO mkdir -p "$INSTALL_ROOT/$VERSION"

  $SUDO install -m 0755 "$YAZI_BIN" "$INSTALL_ROOT/$VERSION/yazi"
  $SUDO install -m 0755 "$YA_BIN" "$INSTALL_ROOT/$VERSION/ya"

  # Install completions if the archive contains them.
  install_completions "$TMPDIR/extracted"

  # Atomically update the current symlink.
  $SUDO ln -sfn "$INSTALL_ROOT/$VERSION" "$INSTALL_ROOT/current"

  $SUDO ln -sfn "$INSTALL_ROOT/current/yazi" "$BIN_DIR/yazi"
  $SUDO ln -sfn "$INSTALL_ROOT/current/ya" "$BIN_DIR/ya"

  # Keep only the newest three binary versions.
  cleanup_old_versions

  install_update_service

  verify_yazi

  echo
  echo "Yazi $VERSION installed successfully."
}

function install_from_source() {
  echo "Installing Yazi from source"

  case "$DISTRO" in
    debian | ubuntu | linuxmint | pop)
      $SUDO apt-get update
      $SUDO apt-get install -y \
        build-essential \
        curl \
        git \
        pkg-config \
        libssl-dev
      ;;
    fedora | rhel | centos | rocky | almalinux)
      $SUDO dnf install -y \
        gcc \
        gcc-c++ \
        make \
        curl \
        git \
        pkg-config \
        openssl-devel
      ;;
    arch)
      $SUDO pacman -S --needed --noconfirm \
        base-devel \
        curl \
        git \
        pkgconf \
        openssl
      ;;
    opensuse* | suse)
      $SUDO zypper --non-interactive install \
        gcc \
        gcc-c++ \
        make \
        curl \
        git \
        pkg-config \
        libopenssl-devel
      ;;
    *)
      echo "WARNING: Please ensure gcc, make, git, curl, pkg-config,"
      echo "and OpenSSL development headers are installed."
      ;;
  esac

  if ! command -v rustup > /dev/null 2>&1; then
    echo "Installing Rust via rustup"

    curl --proto '=https' \
      --tlsv1.2 \
      -sSf \
      https://sh.rustup.rs |
      sh -s -- -y
  fi

  # shellcheck disable=SC1090
  source "${HOME}/.cargo/env"

  rustup toolchain install stable
  rustup default stable

  echo "Installing/updating yazi-build"

  cargo install --force yazi-build

  if [[ ! -x "${HOME}/.cargo/bin/yazi" ||
    ! -x "${HOME}/.cargo/bin/ya" ]]; then
    echo "ERROR: cargo install completed but Yazi binaries were not found."
    exit 1
  fi

  echo
  echo "Yazi installed in ${HOME}/.cargo/bin."
  echo
  echo "Make sure this directory is in PATH:"
  echo "  ${HOME}/.cargo/bin"

  # A source installation is user-local, so install a user systemd timer
  # for automatic cargo updates.
  install_source_update_service

  verify_yazi
}

function install_completions() {
  local root="$1"
  local shell
  local src

  # Yazi's archive layout may change, so locate the completion files rather
  # than assuming a particular directory structure.

  while IFS= read -r -d '' src; do
    shell="$(basename "$src")"

    case "$shell" in
      yazi.bash)
        $SUDO mkdir -p /usr/share/bash-completion/completions
        $SUDO install -m 0644 \
          "$src" \
          /usr/share/bash-completion/completions/yazi
        ;;
      yazi.zsh)
        mkdir -p "${HOME}/.zsh/completions"
        install -m 0644 \
          "$src" \
          "${HOME}/.zsh/completions/_yazi"
        ;;
      yazi.fish)
        mkdir -p "${HOME}/.config/fish/completions"
        install -m 0644 \
          "$src" \
          "${HOME}/.config/fish/completions/yazi.fish"
        ;;
    esac
  done < <(find "$root" -type f \
    \( -name 'yazi.bash' -o -name 'yazi.zsh' -o -name 'yazi.fish' \) \
    -print0)
}

function cleanup_old_versions() {
  local versions
  versions="$(
    $SUDO find "$INSTALL_ROOT" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -printf '%f\n' |
      grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' |
      sort -V
  )"

  mapfile -t versions_array <<< "$versions"

  if ((${#versions_array[@]} <= 3)); then
    return 0
  fi

  for ((i = 0; i < ${#versions_array[@]} - 3; i++)); do
    $SUDO rm -rf "${INSTALL_ROOT}/${versions_array[$i]}"
  done
}

function install_update_service() {
  echo "Installing automatic Yazi update service"

  $SUDO tee "$UPDATE_SCRIPT" > /dev/null << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

INSTALLER="/usr/local/sbin/yazi-update"

if [[ ! -x "$INSTALLER" ]]; then
    echo "Yazi updater not installed."
    exit 1
fi

/usr/local/sbin/yazi-update-run
EOF

  $SUDO chmod 0755 "$UPDATE_SCRIPT"

  $SUDO tee /usr/local/sbin/yazi-update-run > /dev/null << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

REPO="sxyazi/yazi"
INSTALL_ROOT="/usr/local/lib/yazi"
BIN_DIR="/usr/local/bin"

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        YAZI_ARCH="x86_64"
        ;;
    aarch64|arm64)
        YAZI_ARCH="aarch64"
        ;;
    *)
        echo "Automatic binary updates are unsupported for architecture: $ARCH"
        exit 0
        ;;
esac

command -v curl >/dev/null
command -v jq >/dev/null
command -v unzip >/dev/null
command -v sha256sum >/dev/null

VERSION="$(
    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${REPO}/releases/latest" |
    jq -r '.tag_name'
)"

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    echo "Could not determine latest Yazi release."
    exit 1
fi

CURRENT=""

if [[ -L "${INSTALL_ROOT}/current" ]]; then
    CURRENT="$(basename "$(readlink -f "${INSTALL_ROOT}/current")")"
fi

if [[ "$CURRENT" == "$VERSION" ]]; then
    echo "Yazi $VERSION is already installed."
    exit 0
fi

ASSET="yazi-${YAZI_ARCH}-unknown-linux-musl.zip"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

echo "Updating Yazi: ${CURRENT:-none} -> $VERSION"

curl -fL \
    --retry 5 \
    --retry-delay 2 \
    --retry-connrefused \
    -o "$TMPDIR/$ASSET" \
    "$URL"

curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${REPO}/releases/tags/${VERSION}" \
    -o "$TMPDIR/release.json"

EXPECTED="$(
    jq -r --arg asset "$ASSET" '
        .assets[]
        | select(.name == $asset)
        | .digest
        | sub("^sha256:"; "")
    ' "$TMPDIR/release.json"
)"

ACTUAL="$(sha256sum "$TMPDIR/$ASSET" | awk '{print $1}')"

if [[ -z "$EXPECTED" || "$EXPECTED" == "null" ]]; then
    echo "Could not obtain release digest."
    exit 1
fi

if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "SHA-256 verification failed."
    exit 1
fi

unzip -q "$TMPDIR/$ASSET" -d "$TMPDIR/extracted"

YAZI_BIN="$(find "$TMPDIR/extracted" -type f -name yazi -print -quit)"
YA_BIN="$(find "$TMPDIR/extracted" -type f -name ya -print -quit)"

[[ -n "$YAZI_BIN" ]]
[[ -n "$YA_BIN" ]]

chmod +x "$YAZI_BIN" "$YA_BIN"

"$YAZI_BIN" --version
"$YA_BIN" --version

mkdir -p "$INSTALL_ROOT/$VERSION"

install -m 0755 "$YAZI_BIN" "$INSTALL_ROOT/$VERSION/yazi"
install -m 0755 "$YA_BIN" "$INSTALL_ROOT/$VERSION/ya"

ln -sfn "$INSTALL_ROOT/$VERSION" "$INSTALL_ROOT/current"
ln -sfn "$INSTALL_ROOT/current/yazi" "$BIN_DIR/yazi"
ln -sfn "$INSTALL_ROOT/current/ya" "$BIN_DIR/ya"

echo "Yazi $VERSION installed."
EOF

  $SUDO chmod 0755 /usr/local/sbin/yazi-update-run

  $SUDO tee "$SYSTEMD_SERVICE" > /dev/null << EOF
[Unit]
Description=Update Yazi
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${UPDATE_SCRIPT}
EOF

  $SUDO tee "$SYSTEMD_TIMER" > /dev/null << 'EOF'
[Unit]
Description=Weekly Yazi update check

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=2h

[Install]
WantedBy=timers.target
EOF

  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now yazi-update.timer

  echo "Automatic Yazi updates enabled."
}

function install_source_update_service() {
  mkdir -p "${HOME}/.config/systemd/user"

  cat > "${HOME}/.config/systemd/user/yazi-update.service" << 'EOF'
[Unit]
Description=Update Yazi from crates.io

[Service]
Type=oneshot
ExecStart=/bin/sh -lc 'source "$HOME/.cargo/env" && cargo install --force yazi-build'
EOF

  cat > "${HOME}/.config/systemd/user/yazi-update.timer" << 'EOF'
[Unit]
Description=Weekly Yazi source update

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=2h

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now yazi-update.timer

  echo "Automatic source updates enabled."
}

function disable_binary_updater() {
  $SUDO systemctl disable --now yazi-update.timer 2> /dev/null || true
  $SUDO rm -f \
    "$SYSTEMD_SERVICE" \
    "$SYSTEMD_TIMER" \
    "$UPDATE_SCRIPT" \
    /usr/local/sbin/yazi-update-run

  $SUDO systemctl daemon-reload 2> /dev/null || true
}

function verify_yazi() {
  local verify_config
  local verify_status=0

  echo
  echo "Verifying installation"

  if ! command -v yazi > /dev/null 2>&1; then
    echo "ERROR: yazi is not in PATH."
    exit 1
  fi

  if ! command -v ya > /dev/null 2>&1; then
    echo "ERROR: ya is not in PATH."
    exit 1
  fi

  ## Verify the binaries without loading the user's Yazi configuration.
  verify_config="$(mktemp -d)"

  echo

  if ! XDG_CONFIG_HOME="$verify_config" yazi --version; then
    verify_status=1
  fi

  if ! XDG_CONFIG_HOME="$verify_config" ya --version; then
    verify_status=1
  fi

  rm -rf "$verify_config"

  if ((verify_status != 0)); then
    echo "ERROR: Yazi installation verification failed."
    exit 1
  fi

  echo
  echo "Yazi installation verified."
}

########
# Main #
########

if ((USE_FLATPAK)); then
  install_flatpak
  exit 0
fi

case "$DISTRO" in
  arch)
    install_native_arch
    ;;

  fedora | rhel | centos | rocky | almalinux)
    install_native_dnf
    ;;

  opensuse* | suse)
    install_native_opensuse
    ;;

  nixos)
    echo "NixOS detected."
    echo
    echo "Yazi should be installed through Nix/NixOS configuration."
    echo "The upstream documentation provides a Nix module."
    exit 1
    ;;

  *)
    if [[ "$ID_LIKE" == *arch* ]]; then
      install_native_arch
    elif [[ "$ID_LIKE" == *fedora* || "$ID_LIKE" == *rhel* ]]; then
      install_native_dnf
    else
      ## Debian, Ubuntu, Raspberry Pi OS, and unknown Linux systems
      #  get the portable Musl binary.
      install_musl
    fi
    ;;
esac
