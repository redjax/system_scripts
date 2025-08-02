#!/bin/bash

set -e

function echo_bashrc_lines() {
    echo ""
    echo "To source Homebrew on shell startup (making the 'brew' command available), add the following to your ~/.bashrc:"
    echo ""
    echo "echo 'eval \"export HOMEBREW_PREFIX=\"/home/linuxbrew/.linuxbrew\";"
    echo "export HOMEBREW_CELLAR=\"/home/linuxbrew/.linuxbrew/Cellar\";"
    echo "export HOMEBREW_REPOSITORY=\"/home/linuxbrew/.linuxbrew/Homebrew\";"
    echo "export PATH=\"/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin\${PATH+:\$PATH}\";"
    echo "[ -z \"\${MANPATH-}\" ] || export MANPATH=\":\${MANPATH#:}\";"
    echo "export INFOPATH=\"/home/linuxbrew/.linuxbrew/share/info:\${INFOPATH:-}\";\"' >> \$HOME/.bashrc"
    echo ""
}

if command -v brew &>/dev/null || [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  echo "Brew is already installed."
  echo "If the command is not working, make sure to add the following to your ~/.bashrc: "
  
  echo_bashrc_lines

  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

## Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

## Detect distro using /etc/os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO_ID=$ID
else
  echo "Cannot detect Linux distribution."
  exit 1
fi

echo "Curling & installing Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [[ $? -ne 0 ]]; then
  echo "Failed installing homebrew."
  exit 1
fi

read -p "Install homebrew gcc? (Y/n)" install_homebrew_gcc
case $install_homebrew_gcc in
  [Yy]|[Yy][Ee][Ss])
    /home/linuxbrew/.linuxbrew/bin/brew install gcc
    if [[ $? -ne 0 ]]; then
      echo "Failed installing gcc with homebrew."
      exit 1
    else
      echo "gcc installed with homebrew."
    fi
    ;;
  [Nn]|[Nn][Oo])
    echo "Skipping gcc install."
    exit 0
    ;;
esac

echo ""
echo "Homebrew install completed."
echo ""

echo_bashrc_lines

exit 0

