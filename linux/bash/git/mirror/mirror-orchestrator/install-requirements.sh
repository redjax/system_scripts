#!/usr/bin/env bash
set -euo pipefail

##########################################################
# Installs requirements for mirror-orchestrator scripts. #
##########################################################

YQ_VERSION="latest"
FORCE_INSTALL=0
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

function log() {
  printf '[INFO] %s\n' "$*"
}

function warn() {
  printf '[WARN] %s\n' "$*" >&2
}

function err() {
  printf '[ERROR] %s\n' "$*" >&2
}

function usage() {
  cat <<'EOF'
Usage:
  install-requirements.sh [options]

Options:
  --version <vX.Y.Z|latest>  yq version to install (default: latest)
  --force                    Reinstall yq even if compatible version is present
  -h, --help                 Show this help

Environment:
  INSTALL_DIR                Destination directory for yq (default: /usr/local/bin)
EOF
}

function has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

function need_cmd() {
  local cmd="$1"
  local pkg_hint="$2"

  if ! has_cmd "$cmd"; then
    err "Missing required command: ${cmd}"
    err "Install it first. Hint: ${pkg_hint}"
    exit 1
  fi
}

function run_privileged() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
    return
  fi

  if has_cmd sudo; then
    sudo "$@"
    return
  fi

  err "Need elevated privileges to install packages, but sudo is not available"
  exit 1
}

function detect_pkg_manager() {
  if has_cmd apt-get; then
    echo "apt"
    return
  fi
  if has_cmd dnf; then
    echo "dnf"
    return
  fi
  if has_cmd yum; then
    echo "yum"
    return
  fi
  if has_cmd pacman; then
    echo "pacman"
    return
  fi
  if has_cmd zypper; then
    echo "zypper"
    return
  fi
  if has_cmd apk; then
    echo "apk"
    return
  fi
  if has_cmd brew; then
    echo "brew"
    return
  fi

  echo "unknown"
}

function install_os_package() {
  local package="$1"
  local manager

  manager="$(detect_pkg_manager)"
  case "$manager" in
    apt)
      run_privileged apt-get update -y
      run_privileged apt-get install -y "$package"
      ;;
    dnf)
      run_privileged dnf install -y "$package"
      ;;
    yum)
      run_privileged yum install -y "$package"
      ;;
    pacman)
      run_privileged pacman -Sy --noconfirm "$package"
      ;;
    zypper)
      run_privileged zypper --non-interactive install "$package"
      ;;
    apk)
      run_privileged apk add --no-cache "$package"
      ;;
    brew)
      brew install "$package"
      ;;
    *)
      err "No supported package manager found to install: ${package}"
      return 1
      ;;
  esac
}

function ensure_downloader() {
  if has_cmd curl || has_cmd wget; then
    return 0
  fi

  warn "Neither curl nor wget is installed; attempting to install curl"
  install_os_package "curl" || {
    warn "Failed to install curl; attempting wget"
    install_os_package "wget" || {
      err "Unable to install curl or wget automatically"
      exit 1
    }
  }
}

function ensure_tool_installed() {
  local tool="$1"
  local package_primary="$2"
  local package_fallback="${3:-}"

  if has_cmd "$tool"; then
    return 0
  fi

  warn "${tool} is missing; attempting installation (${package_primary})"
  if install_os_package "$package_primary"; then
    return 0
  fi

  if [[ -n "$package_fallback" ]]; then
    warn "Primary package failed; attempting fallback package (${package_fallback})"
    if install_os_package "$package_fallback"; then
      return 0
    fi
  fi

  err "Failed to install ${tool} automatically"
  return 1
}

function detect_os() {
  local raw
  raw="$(uname -s | tr '[:upper:]' '[:lower:]')"

  case "$raw" in
    linux) echo "linux" ;;
    darwin) echo "darwin" ;;
    *)
      err "Unsupported OS: ${raw}. Supported: linux, darwin"
      exit 1
      ;;
  esac
}

function detect_arch() {
  local raw
  raw="$(uname -m | tr '[:upper:]' '[:lower:]')"

  case "$raw" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv7|armhf|armv6l|armv6) echo "arm" ;;
    i386|i686) echo "386" ;;
    *)
      err "Unsupported architecture: ${raw}"
      exit 1
      ;;
  esac
}

function is_compatible_yq_installed() {
  if ! has_cmd yq; then
    return 1
  fi

  # Mike Farah yq v4 supports `eval` and `--null-input`.
  if yq eval --null-input '.ok = true' >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

function download_file() {
  local url="$1"
  local out="$2"

  if has_cmd curl; then
    curl -fsSL "$url" -o "$out"
    return 0
  fi

  if has_cmd wget; then
    wget -qO "$out" "$url"
    return 0
  fi

  err "Neither curl nor wget is available to download yq"
  exit 1
}

function install_binary() {
  local src="$1"
  local dest_dir="$2"
  local dest_file="${dest_dir}/yq"

  mkdir -p "$dest_dir"
  chmod +x "$src"

  if [[ -w "$dest_dir" ]]; then
    install -m 0755 "$src" "$dest_file"
    return 0
  fi

  if has_cmd sudo; then
    sudo install -m 0755 "$src" "$dest_file"
    return 0
  fi

  err "Destination not writable and sudo not available: ${dest_dir}"
  exit 1
}

function main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        YQ_VERSION="${2:-}"
        if [[ -z "$YQ_VERSION" ]]; then
          err "--version requires a value"
          exit 2
        fi
        shift 2
        ;;
      --force)
        FORCE_INSTALL=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        err "Unknown argument: $1"
        usage >&2
        exit 2
        ;;
    esac
  done

  need_cmd bash "Install bash from your system package manager"
  
  ensure_tool_installed git git || {
    err "Install manually: apt install git | dnf install git | pacman -S git | brew install git"
    exit 1
  }

  ensure_tool_installed flock util-linux flock || {
    err "Install manually: apt install util-linux | dnf install util-linux | pacman -S util-linux | brew install flock"
    exit 1
  }

  need_cmd uname "coreutils (usually preinstalled)"
  need_cmd mktemp "coreutils (usually preinstalled)"
  need_cmd install "coreutils (usually preinstalled)"
  ensure_downloader

  if [[ "$FORCE_INSTALL" -eq 0 ]] && is_compatible_yq_installed; then
    log "Compatible yq already installed: $(yq --version 2>/dev/null || echo 'unknown version')"
    exit 0
  fi

  local os
  local arch
  local asset
  local url
  local tmp

  os="$(detect_os)"
  arch="$(detect_arch)"
  asset="yq_${os}_${arch}"

  if [[ "$YQ_VERSION" == "latest" ]]; then
    url="https://github.com/mikefarah/yq/releases/latest/download/${asset}"
  else
    url="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${asset}"
  fi

  log "Installing Mike Farah yq (${YQ_VERSION}) for ${os}/${arch}"
  log "Download URL: ${url}"

  tmp="$(mktemp)"
  trap 'rm -f "${tmp:-}"' EXIT

  download_file "$url" "$tmp"
  install_binary "$tmp" "$INSTALL_DIR"

  ## If INSTALL_DIR is not on PATH, still verify by direct path.
  local installed_path="${INSTALL_DIR}/yq"
  if [[ -x "$installed_path" ]]; then
    if "$installed_path" eval --null-input '.ok = true' >/dev/null 2>&1; then
      log "Installed compatible yq at ${installed_path}"
      log "Version: $($installed_path --version 2>/dev/null || echo 'unknown')"
    else
      err "Installed yq but compatibility check failed at ${installed_path}"
      exit 1
    fi
  else
    err "Installation did not produce executable: ${installed_path}"
    exit 1
  fi

  if ! has_cmd yq || ! yq eval --null-input '.ok = true' >/dev/null 2>&1; then
    warn "Your current PATH may prioritize another yq binary."
    warn "Use this path explicitly or adjust PATH: ${installed_path}"
  fi

  log "All required tools are present (bash, git, flock, yq)"
}

main "$@"
