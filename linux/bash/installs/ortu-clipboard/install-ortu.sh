#!/usr/bin/env bash
set -Eeuo pipefail

REPO="abhijith-p-subash/ortu"
APP_NAME="Ortu"
TMP_DIR="${TMPDIR:-/tmp}/ortu-installer"

readonly REPO
readonly APP_NAME
readonly TMP_DIR

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

errexit() {
    echo "[ERROR] $*" >&2
    exit 1
}

info() {
    echo "[INFO] $*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    command_exists "$1" || errexit "Required command '$1' is not installed."
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        arm64|aarch64)
            echo "aarch64"
            ;;
        *)
            errexit "Unsupported CPU architecture: $(uname -m)"
            ;;
    esac
}

detect_linux_family() {
    [[ -f /etc/os-release ]] || {
        echo "unknown"
        return
    }

    # shellcheck disable=SC1091
    source /etc/os-release

    case "${ID:-}" in
        arch|manjaro|endeavouros|garuda)
            echo "arch"
            ;;

        debian|ubuntu|linuxmint|pop|elementary|neon)
            echo "debian"
            ;;

        fedora|rhel|rocky|almalinux|nobara)
            echo "fedora"
            ;;

        opensuse-tumbleweed|opensuse-leap|opensuse)
            echo "opensuse"
            ;;

        *)
            # Check ID_LIKE for derivatives.
            case "${ID_LIKE:-}" in
                *arch*)
                    echo "arch"
                    ;;
                *debian*|*ubuntu*)
                    echo "debian"
                    ;;
                *fedora*|*rhel*)
                    echo "fedora"
                    ;;
                *suse*)
                    echo "opensuse"
                    ;;
                *)
                    echo "unknown"
                    ;;
            esac
            ;;
    esac
}

latest_release_json() {
    require_command curl

    curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: ortu-installer" \
        "https://api.github.com/repos/${REPO}/releases/latest"
}

download_asset() {
    local asset_url="$1"
    local destination="$2"

    require_command curl

    info "Downloading $(basename "$destination")"
    curl -fL \
        --retry 3 \
        --retry-delay 2 \
        --progress-bar \
        "$asset_url" \
        -o "$destination"
}

install_macos_brew() {
    if ! command_exists brew; then
        return 1
    fi

    ## Only use Homebrew if Ortu is actually available.
    if brew info --cask ortu >/dev/null 2>&1; then
        info "Installing Ortu through Homebrew"
        brew install --cask ortu
        return 0
    fi

    if brew info ortu >/dev/null 2>&1; then
        info "Installing Ortu through Homebrew"
        brew install ortu
        return 0
    fi

    return 1
}

install_macos_dmg() {
    local arch="$1"
    local json asset_url asset_name dmg mount_point app_path

    require_command jq
    require_command hdiutil
    require_command ditto

    json="$(latest_release_json)"

    if [[ "$arch" == "aarch64" ]]; then
        asset_url="$(
            jq -r '
                .assets[]
                | select(.name | test("(?i)(aarch64|arm64).*\\.dmg$"))
                | .browser_download_url
            ' <<<"$json" | head -n1
        )"
    else
        asset_url="$(
            jq -r '
                .assets[]
                | select(.name | test("(?i)(x64|x86_64|amd64).*\\.dmg$"))
                | .browser_download_url
            ' <<<"$json" | head -n1
        )"
    fi

    [[ -n "$asset_url" && "$asset_url" != "null" ]] ||
        errexit "Could not find a macOS DMG for architecture $arch."

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"

    download_asset "$asset_url" "$TMP_DIR/$asset_name"

    mount_point="$(
        hdiutil attach "$TMP_DIR/$asset_name" \
            -nobrowse \
            -readonly |
            awk '/\/Volumes\// {print substr($0, index($0,$3)); exit}'
    )"

    [[ -n "$mount_point" ]] || errexit "Could not mount $asset_name."

    cleanup_dmg() {
        hdiutil detach "$mount_point" -quiet || true
    }
    trap cleanup_dmg EXIT

    app_path="$(find "$mount_point" -maxdepth 2 -name '*.app' -print -quit)"

    [[ -n "$app_path" ]] ||
        errexit "Could not find an .app inside the Ortu DMG."

    info "Installing Ortu into /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "$app_path" "/Applications/${APP_NAME}.app"

    ## Downloaded unsigned applications may receive a quarantine attribute.
    #  Do not silently disable Gatekeeper; let macOS decide what to do.
    info "Ortu installed."
}

install_debian() {
    local json asset_url asset_name deb

    require_command jq

    json="$(latest_release_json)"

    case "$(detect_arch)" in
        x86_64)
            asset_url="$(
                jq -r '
                    .assets[]
                    | select(.name | test("(?i)(amd64|x86_64).*\\.deb$"))
                    | .browser_download_url
                ' <<<"$json" | head -n1
            )"
            ;;
        aarch64)
            asset_url="$(
                jq -r '
                    .assets[]
                    | select(.name | test("(?i)(arm64|aarch64).*\\.deb$"))
                    | .browser_download_url
                ' <<<"$json" | head -n1
            )"
            ;;
    esac

    [[ -n "$asset_url" && "$asset_url" != "null" ]] ||
        errexit "No suitable Ortu .deb found for $(detect_arch)."

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"
    deb="$TMP_DIR/$asset_name"

    download_asset "$asset_url" "$deb"

    info "Installing Ortu with APT"
    sudo apt-get install -y "$deb"

    info "Ortu installed."
    echo
    echo "NOTE: APT owns this installation, but Ortu is not currently"
    echo "being installed from an Ortu APT repository. Therefore:"
    echo
    echo "    sudo apt upgrade"
    echo
    echo "will NOT necessarily upgrade Ortu."
}

install_fedora_or_opensuse() {
    local json asset_url asset_name rpm

    require_command jq

    json="$(latest_release_json)"

    asset_url="$(
        jq -r '
            .assets[]
            | select(.name | test("(?i)\\.rpm$"))
            | .browser_download_url
        ' <<<"$json" | head -n1
    )"

    [[ -n "$asset_url" && "$asset_url" != "null" ]] ||
        return 1

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"
    rpm="$TMP_DIR/$asset_name"

    download_asset "$asset_url" "$rpm"

    if [[ "$(detect_linux_family)" == "fedora" ]]; then
        info "Installing Ortu with DNF"
        sudo dnf install -y "$rpm"
    else
        require_command zypper
        info "Installing Ortu with Zypper"
        sudo zypper --non-interactive install "$rpm"
    fi

    info "Ortu installed."
    echo
    echo "NOTE: The package manager owns this installation, but the"
    echo "GitHub RPM is not a configured package repository."
    echo "Normal system upgrades will not necessarily update Ortu."
}

install_arch_fallback() {
    local json asset_url asset_name appimage

    require_command jq

    json="$(latest_release_json)"

    asset_url="$(
        jq -r '
            .assets[]
            | select(.name | test("(?i)(AppImage)$"))
            | select(.name | test("(?i)(x86_64|amd64|aarch64|arm64)"))
            | .browser_download_url
        ' <<<"$json" | head -n1
    )"

    [[ -n "$asset_url" && "$asset_url" != "null" ]] ||
        errexit "No suitable Ortu AppImage found."

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"
    appimage="$TMP_DIR/$asset_name"

    download_asset "$asset_url" "$appimage"
    chmod +x "$appimage"

    local install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"

    cp "$appimage" "$install_dir/ortu.AppImage"

    info "Installed Ortu AppImage to $install_dir/ortu.AppImage"

    if [[ ":${PATH}:" != *":${install_dir}:"* ]]; then
        echo
        echo "Add this to your shell configuration:"
        echo
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    fi
}

install_arch() {
    if command_exists yay; then
        info "Installing Ortu through yay/AUR"
        yay -S --needed ortu
        return
    fi

    if command_exists paru; then
        info "Installing Ortu through paru/AUR"
        paru -S --needed ortu
        return
    fi

    echo "No AUR helper (yay/paru) found."
    echo "Falling back to the official Ortu AppImage."
    install_arch_fallback
}

main() {
    local os arch family

    os="$(uname -s)"
    arch="$(detect_arch)"

    case "$os" in
        Darwin)
            info "Detected macOS ($arch)"

            if install_macos_brew; then
                info "Ortu installed through Homebrew."
            else
                echo "Ortu is not currently available from your Homebrew installation."
                echo "Falling back to the official DMG."
                install_macos_dmg "$arch"
            fi
            ;;

        Linux)
            family="$(detect_linux_family)"
            info "Detected Linux family: $family ($arch)"

            case "$family" in
                arch)
                    install_arch
                    ;;

                debian)
                    install_debian
                    ;;

                fedora|opensuse)
                    if ! install_fedora_or_opensuse; then
                        echo "No suitable RPM was found."
                        echo "AppImage fallback is not implemented for this package."
                        errexit "Unable to install Ortu on this system."
                    fi
                    ;;

                *)
                    install_arch_fallback
                    ;;
            esac
            ;;

        *)
            errexit "Unsupported operating system: $os"
            ;;
    esac
}

main "$@"
