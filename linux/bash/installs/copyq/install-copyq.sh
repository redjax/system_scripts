#!/usr/bin/env bash
set -Eeuo pipefail

COPYQ_FLATPAK_ID="com.github.hluk.copyq"
COPYQ_GNOME_SHORTCUT_PATH="$HOME/.config/copyq"

readonly COPYQ_FLATPAK_ID
readonly COPYQ_GNOME_SHORTCUT_PATH

TMP_DIR="${TMPDIR:-/tmp}/copyq-installer"

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

warn() {
    echo "warning: $*" >&2
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
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
            echo "unknown"
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

is_gnome_wayland() {
    [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] &&
        [[ "${XDG_CURRENT_DESKTOP:-}" =~ GNOME|gnome ]]
}

ensure_flatpak() {
    if command_exists flatpak; then
        return 0
    fi

    info "Flatpak is not installed."

    case "$(detect_linux_family)" in
        debian)
            sudo apt-get update
            sudo apt-get install -y flatpak
            ;;

        fedora)
            sudo dnf install -y flatpak
            ;;

        arch)
            sudo pacman -Sy --needed --noconfirm flatpak
            ;;

        opensuse)
            sudo zypper --non-interactive install flatpak
            ;;

        *)
            errexit "Flatpak is not installed and the Linux distribution is unknown."
            ;;
    esac
}

ensure_flathub() {
    if flatpak remotes --columns=name 2>/dev/null |
        grep -qx "flathub"; then
        return 0
    fi

    info "Adding Flathub remote"

    flatpak remote-add \
        --if-not-exists \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_flatpak() {
    ensure_flatpak
    ensure_flathub

    info "Installing CopyQ from Flathub"

    flatpak install \
        --user \
        -y \
        flathub \
        "$COPYQ_FLATPAK_ID"

    COPYQ_MODE="flatpak"
}

install_debian() {
    info "Installing CopyQ from APT"

    sudo apt-get update
    sudo apt-get install -y copyq

    COPYQ_MODE="native"
}

install_fedora() {
    info "Installing CopyQ from DNF"

    sudo dnf install -y copyq

    COPYQ_MODE="native"
}

install_arch() {
    info "Installing CopyQ from Pacman"

    sudo pacman -Sy --needed --noconfirm copyq

    COPYQ_MODE="native"
}

install_opensuse() {
    info "Installing CopyQ from Zypper"

    sudo zypper --non-interactive install copyq

    COPYQ_MODE="native"
}

install_native_linux() {
    case "$(detect_linux_family)" in
        debian)
            install_debian
            ;;

        fedora)
            install_fedora
            ;;

        arch)
            install_arch
            ;;

        opensuse)
            install_opensuse
            ;;

        *)
            return 1
            ;;
    esac
}

install_linux() {
    local family

    family="$(detect_linux_family)"

    info "Detected Linux family: $family"
    info "Desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    info "Session: ${XDG_SESSION_TYPE:-unknown}"
    info "Architecture: $(detect_arch)"

    ## CopyQ's GNOME clipboard extension cannot be registered from a Flatpak.
    #  Native installation is preferred specifically for GNOME + # Wayland.
    if is_gnome_wayland; then
        info "[WARNING] GNOME + Wayland detected."
        info "Preferring native CopyQ package for GNOME clipboard integration."

        if install_native_linux; then
            return
        fi

        warn "No supported native package was found."
        warn "Falling back to Flatpak."
        warn "GNOME clipboard monitoring may not work correctly in Flatpak."

        install_flatpak
        return
    fi

    ## For other Linux environments, honor the user's Flatpak-first preference.
    if install_flatpak; then
        return
    fi

    warn "Flatpak installation failed; trying native package."

    if install_native_linux; then
        return
    fi

    errexit "Could not install CopyQ."
}

install_macos() {
    if ! command_exists brew; then
        errexit "Homebrew is required on macOS. Install Homebrew first."
    fi

    info "Installing CopyQ through Homebrew"

    brew install --cask copyq

    COPYQ_MODE="native"
}

copyq_cmd() {
    case "${COPYQ_MODE:-}" in
        flatpak)
            flatpak run \
                "$COPYQ_FLATPAK_ID" \
                "$@"
            ;;

        native)
            command copyq "$@"
            ;;

        *)
            errexit "CopyQ installation mode has not been initialized."
            ;;
    esac
}

start_copyq() {
    info "Starting CopyQ"

    case "${COPYQ_MODE:-}" in
        flatpak)
            flatpak run "$COPYQ_FLATPAK_ID" >/dev/null 2>&1 &
            ;;

        native)
            copyq >/dev/null 2>&1 &
            ;;

        *)
            errexit "Unknown CopyQ installation mode."
            ;;
    esac

    ## Give the CopyQ server a moment to start before issuing configuration commands.
    for _ in {1..20}; do
        if copyq_cmd info >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.25
    done

    warn "CopyQ did not respond to its CLI after startup."
    return 1
}

configure_copyq() {
    info "Applying initial CopyQ configuration"

    ## Hide the main window at startup.
    copyq_cmd config hide_main_window true || true

    ## Do not assign Super+V inside CopyQ on Wayland.
    #  The desktop/compositor should own the shortcut.
    if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        info "Wayland detected; leaving CopyQ's global shortcut unassigned."
    fi
}

configure_xdg_autostart() {
    local autostart_dir
    local desktop_file

    autostart_dir="$HOME/.config/autostart"
    desktop_file="$autostart_dir/copyq.desktop"

    mkdir -p "$autostart_dir"

    info "Configuring CopyQ to start at login"

    if [[ "$COPYQ_MODE" == "flatpak" ]]; then
        cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=CopyQ
Comment=Clipboard Manager
Exec=flatpak run $COPYQ_FLATPAK_ID
Icon=com.github.hluk.copyq
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
    else
        cat > "$desktop_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=CopyQ
Comment=Clipboard Manager
Exec=copyq
Icon=copyq
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
    fi
}

configure_gnome_shortcut() {
    ## GNOME stores custom shortcuts in:
    #    org.gnome.settings-daemon.plugins.media-keys custom-keybindings
    #
    # Create Super+V -> CopyQ toggle()
    #
    # The shortcut invokes CopyQ externally instead of asking CopyQ itself
    # to capture a global keyboard shortcut.
    command_exists gsettings || {
        warn "gsettings is unavailable; cannot configure GNOME shortcut."
        return 0
    }

    [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || {
        return 0
    }

    [[ "${XDG_CURRENT_DESKTOP:-}" =~ GNOME|gnome ]] || {
        return 0
    }

    local schema="org.gnome.settings-daemon.plugins.media-keys"
    local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/copyq/"
    local existing
    local cleaned
    local command

    if [[ "$COPYQ_MODE" == "flatpak" ]]; then
        command="flatpak run --command=copyq ${COPYQ_FLATPAK_ID} -e \"toggle()\""
    else
        command="copyq -e \"toggle()\""
    fi

    info "Configuring GNOME Super+V -> CopyQ"

    existing="$(gsettings get "$schema" custom-keybindings)"

    ## Avoid adding the same keybinding twice.
    if grep -Fq "$base" <<<"$existing"; then
        info "CopyQ GNOME shortcut already exists."
    else
        if [[ "$existing" == "@as []" || "$existing" == "[]" ]]; then
            cleaned="[]"
        else
            cleaned="$existing"
        fi

        ## gsettings returns something like:
        #
        #  ['/org//custom0/', '/org//custom1/']
        #
        # Use Python only to safely append to the GVariant list.
        if command_exists python3; then
            cleaned="$(
                python3 - "$existing" "$base" <<'PY'
import ast
import sys

value = sys.argv[1]
new_path = sys.argv[2]

if value.startswith("@as "):
    value = value[4:]

try:
    paths = ast.literal_eval(value)
except Exception:
    paths = []

if new_path not in paths:
    paths.append(new_path)

print("[" + ", ".join(repr(x) for x in paths) + "]")
PY
            )"

            gsettings set "$schema" custom-keybindings "$cleaned"
        else
            warn "python3 not found; cannot safely modify GNOME custom shortcuts."
            return 0
        fi
    fi

    local key_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$base"

    gsettings set "$key_schema" name "CopyQ"
    gsettings set "$key_schema" command "$command"
    gsettings set "$key_schema" binding "<Super>v"

    info "GNOME shortcut configured: Super+V"
}

show_summary() {
    echo
    echo "============================="
    echo "CopyQ installation complete"
    echo "============================="
    echo
    echo "Installation:"
    echo "  mode: $COPYQ_MODE"

    if [[ "$COPYQ_MODE" == "flatpak" ]]; then
        echo "  package: $COPYQ_FLATPAK_ID"
        echo "  updates: flatpak update"
    else
        case "$(uname -s)" in
            Linux)
                echo "  updates: your normal system package manager"
                ;;
            Darwin)
                echo "  updates: brew upgrade --cask copyq"
                ;;
        esac
    fi

    echo
    echo "CopyQ configuration:"
    echo "  autostart: enabled"
    echo "  main window: hidden at startup"

    if [[ "${XDG_CURRENT_DESKTOP:-}" =~ GNOME|gnome ]] &&
       [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        echo "  GNOME shortcut: Super+V"
        echo
        echo "Super+V should now open/toggle CopyQ."
    else
        echo
        echo "Global shortcuts are desktop/compositor dependent."
        echo "Configure Super+V through your desktop/window manager."
    fi

    echo
    echo "Useful commands:"
    echo "  copyq toggle"
    echo "  copyq clipboard"
    echo "  copyq size"
    echo
}

main() {
    case "$(uname -s)" in
        Linux)
            install_linux
            ;;

        Darwin)
            install_macos
            ;;

        *)
            errexit "Unsupported operating system: $(uname -s)"
            ;;
    esac

    if start_copyq; then
        configure_copyq
    else
        warn "Skipping runtime configuration because CopyQ did not start."
    fi

    if [[ "$(uname -s)" == "Linux" ]]; then
        configure_xdg_autostart
    fi

    configure_gnome_shortcut

    show_summary
}

main "$@"
