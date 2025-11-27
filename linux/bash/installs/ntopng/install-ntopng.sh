#!/usr/bin/env bash
set -e

echo "[*] Detecting OS"

OS=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt >/dev/null 2>&1; then
    OS="debian"
  elif command -v dnf >/dev/null 2>&1; then
    OS="fedora"
  elif command -v yum >/dev/null 2>&1; then
    OS="centos"
  elif command -v pacman >/dev/null 2>&1; then
    OS="arch"
  else
    echo "Unsupported Linux distro"
    exit 1
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS="mac"
else
  echo "Unsupported OS"
  exit 1
fi

echo "[*] Installing ntopng for: $OS"

case $OS in
  debian)
    echo "[*] Adding ntop APT repo"
    curl -fsSL https://packages.ntop.org/apt/ntop.key | sudo gpg --dearmor -o /usr/share/keyrings/ntop.gpg
    echo "deb [signed-by=/usr/share/keyrings/ntop.gpg] https://packages.ntop.org/apt/stable/$(lsb_release -is | tr 'A-Z' 'a-z') $(lsb_release -cs) main" \
      | sudo tee /etc/apt/sources.list.d/ntop.list >/dev/null

    sudo apt update
    sudo apt install -y ntopng redis-server
    sudo systemctl enable redis-server ntopng
    sudo systemctl start redis-server ntopng
    ;;
  fedora|centos)
    echo "[*] Adding ntop yum repo"
    sudo rpm -Uvh https://packages.ntop.org/rpm/ntop.repo
    sudo $OS install -y ntopng redis
    sudo systemctl enable redis ntopng
    sudo systemctl start redis ntopng
    ;;
  arch)
    echo "[*] Installing from AUR"
    if ! command -v yay >/dev/null; then
      echo "yay must be installed first"
      exit 1
    fi
    yay -S ntopng --noconfirm
    ;;
  mac)
    echo "[*] Installing with Homebrew"
    brew install ntopng redis
    brew services start redis
    brew services start ntopng
    ;;
esac

echo
echo "--------------------------------------------------------------"
echo " ntopng installed!"
echo " Web UI: http://<machine>:3000"
echo " Default login: admin / admin"
echo " Config: /etc/ntopng/ntopng.conf"
echo "--------------------------------------------------------------"
