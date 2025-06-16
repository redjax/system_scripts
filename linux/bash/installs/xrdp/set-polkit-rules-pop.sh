#!/usr/bin/env bash

set -euo pipefail

check_xrdp_installed() {
  echo "Checking if xrdp is already installed"
  if ! dpkg -l | grep -qw xrdp; then
    echo "xrdp is not installed."
    exit 1
  fi
}

configure_startwm_sh() {
  local desktop="$1"
  local startwm="/etc/xrdp/startwm.sh"
  echo "Configuring $startwm for $desktop session"

  if [[ "$desktop" == "pop" ]]; then
    if ! grep -q 'GNOME_SHELL_SESSION_MODE=pop' "$startwm"; then
      sudo sed -i '/^#.*$/a \
export GNOME_SHELL_SESSION_MODE=pop\nexport GDMSESSION=pop\nexport XDG_CURRENT_DESKTOP=pop:GNOME' "$startwm"
      echo "Added Pop!_OS session environment variables."
    else
      echo "Pop!_OS session environment variables already set in startwm.sh."
    fi
  elif [[ "$desktop" == "kde" ]]; then
    if ! grep -q 'startplasma-x11' "$startwm"; then
      sudo sed -i '/^#.*$/a \
export KDE_FULL_SESSION=true\nexport XDG_CURRENT_DESKTOP=KDE\nstartplasma-x11' "$startwm"
      echo "Added KDE session startup to startwm.sh."
    else
      echo "KDE session already configured in startwm.sh."
    fi
  else
    echo "Unknown desktop type: $desktop"
    exit 1
  fi
}

create_polkit_rules() {
  echo "Creating polkit rules to suppress authentication popups"

  local polkit_colord="/etc/polkit-1/localauthority/50-local.d/45-allow.colord.pkla"
  local polkit_pkg="/etc/polkit-1/localauthority/50-local.d/46-allow-update-repo.pkla"

  if [[ ! -f "$polkit_colord" ]]; then
    sudo tee "$polkit_colord" > /dev/null <<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF
    echo "Created $polkit_colord"
  else
    echo "$polkit_colord already exists."
  fi

  if [[ ! -f "$polkit_pkg" ]]; then
    sudo tee "$polkit_pkg" > /dev/null <<EOF
[Allow Package Management all Users]
Identity=unix-user:*
Action=org.freedesktop.packagekit.system-sources-refresh;org.freedesktop.packagekit.system-network-proxy-configure
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF
    echo "Created $polkit_pkg"
  else
    echo "$polkit_pkg already exists."
  fi
}

add_user_to_groups() {
  local user="$1"
  echo "Adding user '$user' to xrdp and ssl-cert groups"
  sudo adduser xrdp ssl-cert

  echo "Adding user '$user' to tsusers and tsadmins groups"
  sudo groupadd -f tsusers
  sudo groupadd -f tsadmins
  sudo usermod -aG tsusers "$user"
  sudo usermod -aG tsadmins "$user"
}

configure_firewall() {
  echo "Checking if UFW firewall is active"
  if sudo ufw status | grep -q "Status: active"; then
    echo "Allowing RDP port 3389 through the firewall"
    sudo ufw allow 3389/tcp
  else
    echo "UFW firewall is not active or not installed. Skipping firewall configuration."
  fi
}

restart_xrdp() {
  echo "Enabling and restarting xrdp service"
  sudo systemctl enable xrdp
  sudo systemctl restart xrdp
}

show_success_message() {
  echo "Installation and configuration complete!"
  echo
  echo "You can now connect to this machine via Remote Desktop (RDP) using its IP address:"
  hostname -I | awk '{print $1}'
  echo
  echo "Remember to log out of your local desktop session before connecting via RDP for best results."
}

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

## entrypoint
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to configure xrdp"
    exit 1
  fi
fi
