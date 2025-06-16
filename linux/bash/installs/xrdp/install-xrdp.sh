#!/usr/bin/env bash

set -euo pipefail

function apt_install_xrdp {
  ## Check if xrdp is already installed
  if dpkg -l | grep -qw xrdp; then
    echo "xrdp is already installed on this system."
    echo "If you want to reconfigure or restart the service, you can do so manually."
    exit 0
  fi

  echo "Updating package lists"
  sudo apt update

  echo "Installing xrdp and desktop dependencies"
  sudo apt install -y xrdp

  ## Ensure the environment variables for Pop!_OS GNOME session are set for RDP
  echo "Patching /etc/xrdp/startwm.sh for Pop!_OS session"
  sudo sed -i '/^#.*$/a \
  export GNOME_SHELL_SESSION_MODE=pop\nexport GDMSESSION=pop\nexport XDG_CURRENT_DESKTOP=pop:GNOME' /etc/xrdp/startwm.sh

  echo "Enabling and starting xrdp service"
  sudo systemctl enable xrdp
  sudo systemctl restart xrdp

  echo "xrdp installation and configuration complete."
  echo "You can now connect to this machine using an RDP client."
  echo "Tip: Log out of the local desktop session before connecting via RDP for best results."
  echo "To check your IP address, run: hostname -I"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  apt_install_xrdp "$@"
  if [[ $? -ne 0 ]]; then
    echo "Failed to install xrdp"
    exit 1
  fi
fi