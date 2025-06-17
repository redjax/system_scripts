#!/usr/bin/env bash

set -euo pipefail

# --- Functions ---

check_xrdp_installed() {
  echo "Checking if xrdp is installed..."
  if ! dpkg -l | grep -qw xrdp; then
    echo "Error: xrdp is not installed. Please install it first (sudo apt install xrdp)."
    exit 1
  fi
}

configure_startwm_sh() {
  local desktop="$1"
  local startwm="/etc/xrdp/startwm.sh"
  echo "Configuring $startwm for $desktop session..."

  sudo cp "$startwm" "$startwm.bak.$(date +%s)" # backup

  if [[ "$desktop" == "pop" ]]; then
    sudo tee "$startwm" > /dev/null <<EOF
#!/bin/sh
export GNOME_SHELL_SESSION_MODE=pop
export GDMSESSION=pop
export XDG_CURRENT_DESKTOP=pop:GNOME
exec gnome-session
EOF
    sudo chmod +x "$startwm"
    echo "Configured Pop!_OS GNOME session."
  elif [[ "$desktop" == "kde" ]]; then
    sudo tee "$startwm" > /dev/null <<EOF
#!/bin/sh
export KDE_FULL_SESSION=true
export XDG_CURRENT_DESKTOP=KDE
exec startplasma-x11
EOF
    sudo chmod +x "$startwm"
    echo "Configured KDE Plasma session."
  else
    echo "Unknown desktop type: $desktop"
    exit 1
  fi
}

create_polkit_rules() {
  echo "Creating polkit rules to suppress authentication popups..."
  local polkit_rule="/etc/polkit-1/rules.d/49-xrdp-nopasswd.rules"
  sudo mkdir -p /etc/polkit-1/rules.d
  sudo tee "$polkit_rule" > /dev/null <<'EOF'
// Allow color management and package management actions for all users
polkit.addRule(function(action, subject) {
    var allowedActions = [
        "org.freedesktop.color-manager.create-device",
        "org.freedesktop.color-manager.create-profile",
        "org.freedesktop.color-manager.delete-device",
        "org.freedesktop.color-manager.delete-profile",
        "org.freedesktop.color-manager.modify-device",
        "org.freedesktop.color-manager.modify-profile",
        "org.freedesktop.packagekit.system-sources-refresh",
        "org.freedesktop.packagekit.system-network-proxy-configure"
    ];
    if (allowedActions.indexOf(action.id) >= 0 && subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF
  sudo chmod 644 "$polkit_rule"
  echo "Created $polkit_rule"
}

add_user_to_groups() {
  local user="$1"
  echo "Adding user '$user' to xrdp and ssl-cert groups..."
  sudo adduser xrdp ssl-cert || true

  echo "Adding user '$user' to tsusers and tsadmins groups..."
  sudo groupadd -f tsusers
  sudo groupadd -f tsadmins
  sudo usermod -aG tsusers "$user"
  sudo usermod -aG tsadmins "$user"
}

configure_firewall() {
  echo "Checking if UFW firewall is active..."
  if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "Allowing RDP port 3389 through the firewall..."
    sudo ufw allow 3389/tcp
  else
    echo "UFW firewall is not active or not installed. Skipping firewall configuration."
  fi
}

restart_xrdp() {
  echo "Enabling and restarting xrdp service..."
  sudo systemctl enable xrdp
  sudo systemctl restart xrdp
}

show_success_message() {
  echo
  echo "XRDP installation and configuration complete!"
  echo "You can now connect to this machine via Remote Desktop (RDP) using its IP address:"
  hostname -I | awk '{print $1}'
  echo
  echo "Remember to log out of your local desktop session before connecting via RDP for best results."
}

# --- Main ---

main() {
  local desktop="${1:-pop}"
  local target_user="${2:-$USER}"

  if [[ "$desktop" != "pop" && "$desktop" != "kde" ]]; then
    echo "Usage: $0 [pop|kde] [username]"
    return 1
  fi

  check_xrdp_installed
  configure_startwm_sh "$desktop"
  create_polkit_rules
  add_user_to_groups "$target_user"
  configure_firewall
  restart_xrdp
  show_success_message
}

# --- Entrypoint ---

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to configure xrdp"
    exit 1
  fi
fi
