#!/bin/bash

# Function to detect the distro ID from /etc/os-release
get_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

# Main installation and setup logic
install_cockpit() {
  DISTRO=$(get_distro)
  echo "Detected Linux distro: $DISTRO"

  case "$DISTRO" in
    fedora|centos|rhel)
      echo "Using DNF/YUM for package management"
      sudo dnf install -y cockpit || sudo yum install -y cockpit
      sudo systemctl enable --now cockpit.socket
      sudo firewall-cmd --permanent --add-service=cockpit
      sudo firewall-cmd --reload
      ;;
    
    ubuntu|debian)
      echo "Using APT for package management"
      sudo apt update
      sudo apt install -y cockpit
      sudo systemctl enable --now cockpit.socket
      # Check if ufw is installed and enable rule
      if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 9090/tcp
      fi
      ;;
    
    *)
      echo "Unsupported or unknown distro: $DISTRO"
      echo "Please install Cockpit manually."
      exit 1
      ;;
  esac

  echo "Cockpit installation and setup complete."
  sudo systemctl status cockpit.socket --no-pager
}

install_cockpit

