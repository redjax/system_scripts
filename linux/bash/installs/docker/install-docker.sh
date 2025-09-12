#!/bin/bash

set -euo pipefail

## Detect distribution info from /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

install_docker_debian_ubuntu() {
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

  curl -fsSL https://download.docker.com/linux/"$ID"/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$ID \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  sudo systemctl enable --now docker
}

install_docker_fedora() {
  sudo dnf -y install dnf-plugins-core
  ## Download the repo file and save it to /etc/yum.repos.d/
  sudo curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
}

install_docker_centos_rocky_redhat() {
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
}

install_docker_opensuse() {
  sudo zypper refresh
  sudo zypper install -y docker
  sudo systemctl enable --now docker
}

install_docker_arch() {
  sudo pacman -Sy --noconfirm docker docker-compose
  sudo systemctl enable --now docker
}

install_docker_alpine() {
  sudo apk update
  sudo apk add docker docker-compose
  sudo rc-update add docker boot
  sudo service docker start
}

echo "Installing Docker"
echo "  Platform: $NAME ($ID)"
echo ""

case "$ID" in
  ubuntu|debian)
    install_docker_debian_ubuntu
    ;;

  fedora)
    install_docker_fedora
    ;;

  centos|rhel|rocky)
    install_docker_centos_rocky_redhat
    ;;

  opensuse*|sles)
    install_docker_opensuse
    ;;

  arch)
    install_docker_arch
    ;;

  alpine)
    install_docker_alpine
    ;;

  *)
    echo "Unsupported or unrecognized distribution: $ID"
    echo "Please install Docker manually for your distribution."
    
    exit 1
    ;;
esac

if [[ $? -ne 0 ]]; then
  echo "Docker installation failed."
  exit 1
fi

echo ""
echo "Docker installed and Docker service started."
read -p "Add your user to the docker group to run docker without sudo? (y/n): " add_to_docker_group
if [[ "$add_to_docker_group" =~ ^[Yy]$ ]]; then
  sudo usermod -aG docker "$USER"
  echo "User $USER added to docker group. You may need to log out and back in for this to take effect. You can also try running: newgrp docker"

else
    echo "To add your user to the docker group without sudo, run the following command:"
    echo "  sudo usermod -aG docker \$USER"
    echo "  To reload your shell without logging out after adding to the docker group, run:"
    echo "  newgrp docker"
fi

echo "Docker installed."
