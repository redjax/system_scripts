#!/bin/bash

set -euo pipefail

install_docker_compose_latest() {
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

if command -v docker compose --version &> /dev/null; then
    echo "Docker Compose is already installed."
    exit 0
fi

install_docker_compose_latest
if [[ $? -ne 0 ]]; then
  echo "Docker Compose installation failed."
  exit 1
fi

## Check if docker-compose plugin is installed; if not, install the latest binary
if ! docker compose version &> /dev/null; then
  echo "Docker Compose plugin not found, installing latest binary..."
  install_docker_compose_latest
fi

echo ""
echo "Docker Compose installed"
