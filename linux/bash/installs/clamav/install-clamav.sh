#!/usr/bin/env bash
set -euo pipefail

detect_pkg_manager() {
    ## Prefer /etc/os-release
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|pop|raspbian)
                echo "apt"
                return 0
                ;;
            rhel|centos|rocky|almalinux|fedora)
                ## dnf first, fallback to yum
                if command -v dnf >/dev/null 2>&1; then
                    echo "dnf"
                else
                    echo "yum"
                fi
                return 0
                ;;
            opensuse*|sles)
                echo "zypper"
                return 0
                ;;
            arch|manjaro|endeavouros)
                echo "pacman"
                return 0
                ;;
        esac
    fi

    ## Fallback: detect by binary
    for m in apt dnf yum zypper pacman; do
        if command -v "$m" >/dev/null 2>&1; then
            echo "$m"
            return 0
        fi
    done

    echo "unknown"
    return 1
}

install_clamav() {
    local pm
    pm="$(detect_pkg_manager)" || {
        printf 'Could not detect a supported package manager.\n' >&2
        exit 1
    }

    case "$pm" in
        apt)
            sudo apt-get update
            ## ClamAV CLI + updater
            sudo apt-get install -y clamav clamav-freshclam
            ;;
        dnf)
            sudo dnf install -y epel-release || true   # no-op on Fedora
            sudo dnf install -y clamav clamav-update
            ;;
        yum)
            sudo yum install -y epel-release || true   # for CentOS/RHEL clones
            sudo yum install -y clamav clamav-update
            ;;
        zypper)
            sudo zypper refresh
            sudo zypper install -y clamav
            ;;
        pacman)
            sudo pacman -Sy --needed --noconfirm clamav
            ;;
        *)
            printf 'Unsupported or unknown package manager: %s\n' "$pm" >&2
            exit 1
            ;;
    esac
}

initial_freshclam_update() {
    local cfg

    if [[ -f /etc/freshclam.conf ]]; then
        cfg=/etc/freshclam.conf
    elif [[ -f /etc/clamav/freshclam.conf ]]; then
        cfg=/etc/clamav/freshclam.conf
    else
        cfg=""
    fi

    if [[ -n "${cfg}" ]]; then
        sudo sed -i 's/^[[:space:]]*Example/#Example/' "$cfg"
    fi

    ## Stop any running freshclam service that might lock the DB
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl stop clamav-freshclam 2>/dev/null || true
        sudo systemctl stop freshclam 2>/dev/null || true
    fi

    sudo freshclam
}

main() {
    install_clamav
    initial_freshclam_update

    echo "ClamAV and freshclam installed and updated."
}

main "$@"
