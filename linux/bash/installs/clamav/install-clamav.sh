#!/usr/bin/env bash
set -euo pipefail


function detect_pkg_manager() {
    ## Prefer /etc/os-release
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|pop|raspbian)
                echo "apt"
                return 0
                ;;
            rhel|centos|rocky|almalinux)
                ## RHEL family, prefers dnf, fallback to yum
                if command -v dnf >/dev/null 2>&1; then
                    echo "dnf-rhel"
                else
                    echo "yum-rhel"
                fi
                return 0
                ;;
            fedora)
                ## Fedora: dnf, no EPEL needed
                echo "dnf-fedora"
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


function install_clamav() {
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
        dnf-fedora)
            ## Fedora: ClamAV is in base repos, no EPEL needed
            sudo dnf install -y clamav clamav-update
            ;;
        dnf-rhel)
            ## RHEL/Rocky/Alma/CentOS: EPEL often required
            sudo dnf install -y epel-release || true
            sudo dnf install -y clamav clamav-update
            ;;
        yum-rhel)
            sudo yum install -y epel-release || true
            sudo yum install -y clamav clamav-update
            ;;
        dnf)
            ## Generic dnf fallback if detect_pkg_manager() hit the binary path
            sudo dnf install -y clamav clamav-update
            ;;
        yum)
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


function install_clamtk() {
    local pm
    pm="$(detect_pkg_manager)" || {
        printf 'Could not detect a supported package manager.\n' >&2
        return 1
    }

    case "$pm" in
        apt)
            sudo apt-get update
            sudo apt-get install -y clamtk
            ;;
        dnf-fedora|dnf-rhel|dnf)
            sudo dnf install -y epel-release || true
            sudo dnf install -y clamtk || {
                echo "ClamTk package not found via dnf." >&2
                return 1
            }
            ;;
        yum-rhel|yum)
            sudo yum install -y epel-release || true
            sudo yum install -y clamtk || {
                echo "ClamTk package not found via yum." >&2
                return 1
            }
            ;;
        zypper)
            sudo zypper refresh
            sudo zypper install -y clamtk || {
                echo "ClamTk package not found via zypper." >&2
                return 1
            }
            ;;
        pacman)
            ## ClamTk may be in community/AUR; keep it best-effort
            sudo pacman -Sy --needed --noconfirm clamtk || {
                echo "ClamTk package not found via pacman." >&2
                return 1
            }
            ;;
        *)
            printf 'ClamTk not available for package manager: %s\n' "$pm" >&2
            return 1
            ;;
    esac
}


function initial_freshclam_update() {
    local cfg=""

    if [[ -f /etc/freshclam.conf ]]; then
        cfg=/etc/freshclam.conf
    elif [[ -f /etc/clamav/freshclam.conf ]]; then
        cfg=/etc/clamav/freshclam.conf
    fi

    if [[ -n "${cfg}" ]]; then
        ## Comment out Example line if present
        sudo sed -i 's/^[[:space:]]*Example/#Example/' "$cfg"
        ## Remove any invalid LogFile line that might have been copied in
        sudo sed -i '/^LogFile[[:space:]]/d' "$cfg" || true
    fi

    ## Stop any running freshclam service that might lock the DB
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl stop clamav-freshclam 2>/dev/null || true
        sudo systemctl stop freshclam 2>/dev/null || true
    fi

    sudo freshclam
}


function main() {
    echo ""
    echo "[ Install ClamAV and freshclam ]"
    echo ""

    install_clamav
    initial_freshclam_update

    ## Ask about ClamTk GUI
    read -r -p "Install ClamTk GUI? (y/n): " install_clamtk_answer
    if [[ "$install_clamtk_answer" =~ ^[Yy]$ ]]; then
        echo "Installing ClamTk"

        if install_clamtk; then
            echo "ClamTk installed successfully."
        else
            echo "ClamTk installation failed or not available."
        fi
    else
        echo "Skipping ClamTk."
    fi

    echo "ClamAV and freshclam installed and updated."
}


main "$@"
