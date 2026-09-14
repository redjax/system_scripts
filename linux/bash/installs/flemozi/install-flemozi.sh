##!/usr/bin/env bash
set -Eeuo pipefail

REPO="KRTirtho/flemozi"
APP_NAME="Flemozi"
TMP_DIR="${TMPDIR:-/tmp}/flemozi-installer"
FLATPAK_ID="dev.krtirtho.Flemozi"

readonly REPO
readonly APP_NAME
readonly TMP_DIR
readonly FLATPAK_ID

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
        -H "User-Agent: flemozi-installer" \
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

    if brew info --cask flemozi >/dev/null 2>&1; then
        info "Installing Flemozi through Homebrew"
        brew install --cask flemozi
        return 0
    fi

    return 1
}

install_macos_dmg() {
    local arch="$1"
    local json asset_url asset_name mount_point app_path

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
        errexit "Could not find a Flemozi DMG for architecture $arch."

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"

    download_asset "$asset_url" "$TMP_DIR/$asset_name"

    mount_point="$(
        hdiutil attach "$TMP_DIR/$asset_name" \
            -nobrowse \
            -readonly |
            awk '/\/Volumes\// {print substr($0, index($0,$3)); exit}'
    )"

    [[ -n "$mount_point" ]] ||
        errexit "Could not mount $asset_name."

    cleanup_dmg() {
        hdiutil detach "$mount_point" -quiet || true
    }
    trap cleanup_dmg EXIT

    app_path="$(find "$mount_point" -maxdepth 2 -name '*.app' -print -quit)"

    [[ -n "$app_path" ]] ||
        errexit "Could not find an .app inside the Flemozi DMG."

    info "Installing Flemozi into /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "$app_path" "/Applications/${APP_NAME}.app"

    info "Flemozi installed."
}

install_flatpak() {
    command_exists flatpak || return 1

    ## Only use this if Flathub is already configured.
    if ! flatpak remote-list | awk '{print $1}' | grep -qx "flathub"; then
        return 1
    fi

    if flatpak remote-info flathub "$FLATPAK_ID" >/dev/null 2>&1; then
        info "Installing Flemozi through Flathub"
        flatpak install -y flathub "$FLATPAK_ID"

        echo
        echo "Flemozi will now be updated with:"
        echo
        echo "    flatpak update"
        echo

        return 0
    fi

    return 1
}

install_arch() {
    if command_exists yay; then
        info "Installing Flemozi through yay/AUR"
        yay -S --needed flemozi
        return 0
    fi

    if command_exists paru; then
        info "Installing Flemozi through paru/AUR"
        paru -S --needed flemozi
        return 0
    fi

    return 1
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
        return 1

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"
    deb="$TMP_DIR/$asset_name"

    download_asset "$asset_url" "$deb"

    info "Installing Flemozi with APT"
    sudo apt-get install -y "$deb"

    echo
    echo "NOTE: APT owns this installation, but this is a locally"
    echo "downloaded package rather than an Ortu/Flemozi APT repository."
    echo "It will not necessarily be updated by 'apt upgrade'."
    echo

    return 0
}

install_rpm() {
    local json asset_url asset_name rpm family

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

    family="$(detect_linux_family)"

    case "$family" in
        fedora)
            info "Installing Flemozi with DNF"
            sudo dnf install -y "$rpm"
            ;;

        opensuse)
            info "Installing Flemozi with Zypper"
            sudo zypper --non-interactive install "$rpm"
            ;;

        *)
            return 1
            ;;
    esac

    echo
    echo "NOTE: This RPM was downloaded directly from GitHub."
    echo "Your package manager owns it, but a configured Flemozi"
    echo "repository is required for automatic future upgrades."
    echo

    return 0
}

install_appimage() {
    local json asset_url asset_name appimage install_dir

    require_command jq

    json="$(latest_release_json)"

    asset_url="$(
        jq -r '
            .assets[]
            | select(.name | test("(?i)AppImage$"))
            | .browser_download_url
        ' <<<"$json" | head -n1
    )"

    [[ -n "$asset_url" && "$asset_url" != "null" ]] ||
        errexit "No Flemozi AppImage found."

    asset_name="$(basename "$asset_url")"
    mkdir -p "$TMP_DIR"

    download_asset "$asset_url" "$TMP_DIR/$asset_name"
    chmod +x "$TMP_DIR/$asset_name"

    install_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir"

    cp "$TMP_DIR/$asset_name" "$install_dir/flemozi.AppImage"

    info "Installed Flemozi to $install_dir/flemozi.AppImage"

    if [[ ":${PATH}:" != *":${install_dir}:"* ]]; then
        echo
        echo 'Add this to your shell configuration:'
        echo
        echo 'export PATH="$HOME/.local/bin:$PATH"'
    fi
}

main() {
    local os family arch

    os="$(uname -s)"
    arch="$(detect_arch)"

    case "$os" in
        Darwin)
            info "Detected macOS ($arch)"

            if install_macos_brew; then
                info "Flemozi installed through Homebrew."
            else
                echo "Flemozi is not currently available from your Homebrew installation."
                echo "Falling back to the official DMG."
                install_macos_dmg "$arch"
            fi
            ;;

        Linux)
            family="$(detect_linux_family)"
            info "Detected Linux family: $family ($arch)"

            case "$family" in
                arch)
                    if install_arch; then
                        info "Flemozi installed through the AUR."
                        echo
                        echo "Future updates:"
                        echo "    yay -Syu"
                        echo "or:"
                        echo "    paru -Syu"
                    elif install_flatpak; then
                        :
                    elif install_appimage; then
                        :
                    else
                        errexit "Unable to install Flemozi."
                    fi
                    ;;

                debian)
                    if install_flatpak; then
                        :
                    elif install_debian; then
                        :
                    else
                        install_appimage
                    fi
                    ;;

                fedora|opensuse)
                    if install_flatpak; then
                        :
                    elif install_rpm; then
                        :
                    else
                        install_appimage
                    fi
                    ;;

                *)
                    if install_flatpak; then
                        :
                    else
                        install_appimage
                    fi
                    ;;
            esac
            ;;

        *)
            errexit "Unsupported operating system: $os"
            ;;
    esac
}

main "$@"
