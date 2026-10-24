#!/usr/bin/env bash
set -uo pipefail

echo "[Install TeX Live ]"

detect_os() {
  case "$(uname -s)" in
    Linux)  echo "linux" ;;
    Darwin) echo "macos" ;;
    *)      echo "unknown" ;;
  esac
}

detect_linux_distro() {
  if [ -r /etc/os-release ]; then
    ## shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

install_texlive_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "[ERROR] Homebrew not found. Install Homebrew from https://brew.sh/ and re-run this script."
    exit 1
  fi

  echo "Installing MacTeX (TeX Live) via Homebrew"
  if ! brew install --cask mactex-no-gui; then
    echo "[ERROR] Failed to install MacTeX via Homebrew."
    exit 1
  fi

  ## Common TeX Live bin path for MacTeX; you may need to adjust based on actual year.
  YEAR="$(date +%Y)"
  TEX_BIN="/usr/local/texlive/${YEAR}/bin/universal-darwin"
  PROFILE="${HOME}/.bashrc"

  if [ -d "$TEX_BIN" ]; then
    if ! grep -q "texlive" "$PROFILE" 2>/dev/null; then
      echo "Adding TeX Live bin to PATH in ${PROFILE}"
      {
        echo ""
        echo "# TeX Live"
        echo "export PATH=\"$TEX_BIN:\$PATH\""
      } >> "$PROFILE"

    else
      echo "TeX Live bin already referenced in ${PROFILE}."

    fi

    echo "TeX Live installed. Restart your shell or run: source ${PROFILE}"
  else
    echo "[ERROR] TeX Live bin directory not found at ${TEX_BIN}."
    echo "Check /usr/local/texlive for the actual install path and update PATH manually."
  fi
}

install_texlive_linux() {
  distro="$(detect_linux_distro)"
  echo "Detected Linux distribution: ${distro}"

  ## Install minimal prerequisites
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing prerequisites via apt-get"

    sudo apt-get update
    if ! sudo apt-get install -y perl wget tar; then
      echo "[ERROR] Failed to install prerequisites with apt-get."
      exit 1
    fi

  elif command -v dnf >/dev/null 2>&1; then
    echo "Installing prerequisites via dnf"

    if ! sudo dnf install -y perl wget tar; then
      echo "[ERROR] Failed to install prerequisites with dnf."
      exit 1
    fi

  elif command -v pacman >/dev/null 2>&1; then
    echo "Installing prerequisites via pacman"

    if ! sudo pacman -Sy --needed --noconfirm perl wget tar; then
      echo "[ERROR] Failed to install prerequisites with pacman."
      exit 1
    fi
  else
    echo "[ERROR] Could not detect package manager. Ensure perl, wget, and tar are installed and re-run."
  fi

  TMPDIR="$(mktemp -d 2>/dev/null || mktemp -d -t texlive)"
  if [ ! -d "$TMPDIR" ]; then
    echo "[ERROR] Failed to create temporary directory."
    exit 1
  fi

  echo "Using temp dir: ${TMPDIR}"
  cd "$TMPDIR" || { echo "[ERROR] Failed to cd into ${TMPDIR}."; exit 1; }

  echo "Downloading latest TeX Live installer from CTAN"
  if ! wget -O install-tl-unx.tar.gz http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz; then
    echo "[ERROR] Failed to download TeX Live installer."
    exit 1
  fi

  echo "Extracting installer..."
  if ! tar -xzf install-tl-unx.tar.gz; then
    echo "[ERROR] Failed to extract TeX Live installer."
    exit 1
  fi

  echo "Looking for installer directory..."
  INSTALL_DIR=$(find . -maxdepth 1 -type d -name 'install-tl*' | head -1)
  if [ -z "$INSTALL_DIR" ]; then
    echo "[ERROR] Could not find installer directory matching 'install-tl-*'."
    echo "Contents of current directory:"
    ls -la
    exit 1
  fi

  echo "Found installer directory: $INSTALL_DIR"
  cd "$INSTALL_DIR" || { echo "[ERROR] Failed to cd into $INSTALL_DIR."; exit 1; }

  echo "Running TeX Live installer (this may take a long time)..."
  if ! sudo perl install-tl -no-gui; then
    echo "[ERROR] TeX Live installer failed."
    exit 1
  fi

  YEAR="$(date +%Y)"
  TEX_BIN="/usr/local/texlive/${YEAR}/bin/x86_64-linux"
  PROFILE="${HOME}/.bashrc"

  if [ -d "$TEX_BIN" ]; then
    if ! grep -q "texlive" "$PROFILE" 2>/dev/null; then
      echo "Adding TeX Live bin to PATH in ${PROFILE}"
      {
        echo ""
        echo "# TeX Live"
        echo "export PATH=\"$TEX_BIN:\$PATH\""
      } >> "$PROFILE"

    else
      echo "TeX Live bin already referenced in ${PROFILE}."

    fi
    echo "TeX Live installed. Restart your shell or run: source ${PROFILE}"
  else
    echo "[ERROR] TeX Live bin directory not found at ${TEX_BIN}."
    echo "Check /usr/local/texlive for the installed year/arch and update PATH manually."
  fi

  echo "Cleaning up temp dir ${TMPDIR}"
  rm -rf "$TMPDIR"
}

main() {
  os="$(detect_os)"
  case "$os" in
    macos)
      echo "Detected macOS."
      install_texlive_macos
      ;;
    linux)
      echo "Detected Linux."
      install_texlive_linux
      ;;
    *)
      echo "[ERROR] Unsupported OS: $(uname -s)."
      exit 1
      ;;
  esac

  echo "Done. Test with: pdflatex --version"
}

main "$@"
