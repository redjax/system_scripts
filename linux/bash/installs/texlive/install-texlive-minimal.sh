#!/usr/bin/env bash

detect_distro() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "${ID_LIKE:-$ID}"
  else
    echo "unknown"
  fi
}

DISTRO=$(detect_distro)
echo "Detected $DISTRO"

case "$DISTRO" in
  debian|ubuntu)
    echo "Installing minimal resume LaTeX for Debian/Ubuntu"
    sudo apt update
    sudo apt install -y \
      texlive-latex-base \
      texlive-latex-recommended \
      texlive-fonts-recommended \
      texlive-latex-extra \
      texlive-fonts-extra \
      texlive-bibtex-extra
    ;;
  fedora|rhel|ol*|centos)
    echo "Installing minimal resume LaTeX for Fedora/RHEL"
    sudo dnf install -y --skip-unavailable \
      texlive-scheme-medium \
      texlive-fonts-recommended \
      texlive-latex-extra \
      texlive-bibtex-extra \
      texlive-xetex-def \
      texlive-luatex
    ;;
  arch)
    echo "Installing minimal resume LaTeX for Arch Linux"
    sudo pacman -Syu --noconfirm \
      texlive-latexextra \
      texlive-fontsextra \
      texlive-bibtexextra
    ;;
  darwin)
    echo "Installing minimal LaTeX for macOS"
    if ! command -v brew >/dev/null; then
      echo "Homebrew required. Install from https://brew.sh/"
      exit 1
    fi
    brew install --cask mactex-no-gui
    ;;
  *)
    echo "Unsupported distro: $DISTRO"
    echo "Manual packages needed: texlive-latex-base, texlive-fonts-recommended, texlive-latex-extra"
    exit 1
    ;;
esac

echo "Done. Test with: pdflatex --version"
