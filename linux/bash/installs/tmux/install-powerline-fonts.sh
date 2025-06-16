#!/bin/bash

if ! command -v git > /dev/null 2>&1; then
  echo "[ERROR] git is not installed"
  exit 1
fi

if ! command -v curl > /dev/null 2>&1; then
  echo "[ERROR] curl is not installed"
  exit 1
fi

if [[ -d /tmp/pl-fonts ]]; then
  echo "Powerline fonts were already downloaded. Attempting to install."
else
    echo "Cloning powerline fonts"
    git clone --depth 1 https://github.com/powerline/fonts /tmp/pl-fonts
    if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed cloning powerline fonts"
    exit 1
    fi
fi

cd /tmp/pl-fonts

echo "Installing powerline fonts"
./install.sh
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed installing powerline fonts"
  exit 1
fi

if [[ ! -d $HOME/.config/fontconfig/conf.d ]]; then
  echo "Creating directory '$HOME/.config/fontconfig/conf.d'"
  mkdir -p $HOME/.config/fontconfig/conf.d
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] error while creating directory '$HOME/.config/fontconfig/conf.d'"
    exit 1
  fi
fi

if [[ ! -f $HOME/.config/fontconfig/conf.d/10-powerline-symbols.conf ]]; then
  echo "Creating file '$HOME/.config/fontconfig/conf.d/10-powerline-symbols.conf'"
  curl -L "https://raw.githubusercontent.com/powerline/powerline/refs/heads/master/font/10-powerline-symbols.conf" \
    -o ~/.config/fontconfig/conf.d/10-powerline-symbols.conf
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] error while creating file '$HOME/.config/fontconfig/conf.d/10-powerline-symbols.conf'"
    exit 1
  fi
fi

echo "Powerline fonts installed"
exit 0
