#!/usr/bin/env bash
set -euo pipefail

detect_os() {
    if command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v dnf &>/dev/null; then
        echo "fedora"
    elif command -v yum &>/dev/null; then
        echo "rhel"
    elif command -v pacman &>/dev/null; then
        echo "arch"
    else
        echo "unknown"
    fi
}

install_packages() {
    case "$OS" in
        debian)
            sudo apt-get update -y
            sudo apt-get install -y clamav clamav-freshclam clamav-daemon clamtk || true
            ;;
        fedora)
            sudo dnf install -y clamav clamav-freshclam clamd clamtk || true
            ;;
        rhel)
            sudo yum install -y epel-release || true
            sudo yum install -y clamav clamav-update clamd clamtk || true
            ;;
        arch)
            sudo pacman -Sy --noconfirm clamav clamtk || true
            ;;
    esac
}

configure_clamd() {
    local CONF=""
    for c in /etc/clamd.conf /etc/clamd.d/scan.conf /etc/clamav/clamd.conf; do
        [[ -f "$c" ]] && CONF="$c"
    done

    [[ -z "$CONF" ]] && return

    sudo sed -i 's/^Example/#Example/' "$CONF"
    sudo sed -i 's/^#LocalSocket/LocalSocket/' "$CONF"

    if ! grep -q "^LocalSocket" "$CONF"; then
        echo "LocalSocket /run/clamd.socket" | sudo tee -a "$CONF" >/dev/null
    fi
}

enable_updates() {
    case "$OS" in
        debian)
            sudo systemctl enable --now clamav-freshclam || true
            ;;
        fedora|rhel)
            sudo tee /etc/cron.daily/freshclam >/dev/null << 'EOF'
#!/bin/sh
/usr/bin/freshclam --quiet
EOF
            sudo chmod +x /etc/cron.daily/freshclam
            ;;
        arch)
            sudo systemctl enable --now freshclam.service || true
            ;;
    esac
}

fanotify_supported() {
    if [[ -d /sys/kernel/fs/fanotify ]]; then
        return 0
    fi

    local KC="/boot/config-$(uname -r)"
    if [[ -f "$KC" ]] && grep -q "CONFIG_FANOTIFY=y" "$KC"; then
        return 0
    fi

    if grep -qi fanotify /proc/filesystems; then
        return 0
    fi

    return 1
}

enable_realtime() {
    if ! fanotify_supported; then
        echo "Real-time scanning not supported by this kernel."
        return
    fi

    sudo tee /etc/systemd/system/clamonacc.service >/dev/null << 'EOF'
[Unit]
Description=ClamAV On-Access Scanner
After=network.target

[Service]
ExecStart=/usr/bin/clamonacc --log=/var/log/clamav/clamonacc.log --recursive=yes --move=/quarantine
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now clamonacc.service
    echo "Real-time scanning enabled."
}

start_clamd() {
    if systemctl list-unit-files | grep -q '^clamd@'; then
        ## enable all clamd@ instances
        for svc in $(systemctl list-unit-files | grep '^clamd@' | awk '{print $1}'); do
            sudo systemctl enable --now "$svc"
        done
    elif systemctl list-unit-files | grep -q '^clamd'; then
        sudo systemctl enable --now clamd || true
    elif systemctl list-unit-files | grep -q '^clamav-daemon'; then
        sudo systemctl enable --now clamav-daemon || true
    else
        echo "No clamd service found to start."
    fi
}


install_clamtk() {
    case "$OS" in
        debian) sudo apt-get install -y clamtk ;;
        fedora) sudo dnf install -y clamtk ;;
        rhel)   sudo yum install -y clamtk || true ;;
        arch)   sudo pacman -Sy --noconfirm clamtk ;;
    esac
}

OS=$(detect_os)
[[ "$OS" == "unknown" ]] && echo "Unsupported distro." && exit 1

echo "Detected OS: $OS"
echo "Installing ClamAV packages"
install_packages

configure_clamd

echo "Running initial freshclam update"
sudo freshclam || true

echo "Enabling automatic updates"
enable_updates

read -rp "Enable real-time scanning? (y/n): " RT
[[ "$RT" =~ ^[Yy]$ ]] && enable_realtime

read -rp "Install ClamTk GUI? (y/n): " GUI
[[ "$GUI" =~ ^[Yy]$ ]] && install_clamtk

start_clamd

echo ""
echo "ClamAV installation complete."
echo "Example scan: sudo clamscan -ri / --log=/var/log/clamav/system-scan.log"
