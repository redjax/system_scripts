#!/bin/bash

install_dir="/opt/devpod"
cli_binary="$install_dir/usr/bin/devpod-cli"
desktop_binary="$install_dir/usr/bin/dev-pod-desktop"
local_bin_dir="/usr/local/bin"
desktop_entry_dir="$HOME/.local/share/applications"
desktop_entry_file="$desktop_entry_dir/devpod-desktop.desktop"
icon_source_dir="$install_dir/usr/share/icons/hicolor"
icon_target_dir="$HOME/.local/share/icons/hicolor"

function install_devpod {
  if ! command -v curl &> /dev/null; then
      echo "curl could not be found, please install curl first."
      exit 1
  fi

  if command -v devpod &> /dev/null || command -v devpod-desktop &> /dev/null; then
      echo "DevPod is already installed."
      exit 0
  fi

  arch=$(uname -m)

  if [[ "$arch" == "x86_64" ]]; then
    echo "Detected AMD/Intel CPU architecture (AMD64)."
    url="https://github.com/loft-sh/devpod/releases/latest/download/DevPod_linux_x86_64.tar.gz"
  elif [[ "$arch" == "aarch64" ]]; then
    echo "Detected ARM64 CPU architecture."
    url="https://github.com/loft-sh/devpod/releases/latest/download/DevPod_linux_arm64.tar.gz"
  else
    echo "Unsupported CPU architecture: $arch"
    exit 1
  fi

  temp_dir=$(mktemp -d)

  echo "Downloading DevPod from $url"
  curl -L -o "$temp_dir/devpod.tar.gz" "$url"
  if [[ $? -ne 0 ]]; then
    echo "Failed to download DevPod."
    rm -rf "$temp_dir"
    exit 1
  fi

  echo "Extracting DevPod to $install_dir"
  sudo mkdir -p "$install_dir"
  sudo tar -xzvf "$temp_dir/devpod.tar.gz" -C "$install_dir"
  if [[ $? -ne 0 ]]; then
    echo "Failed to extract DevPod."
    rm -rf "$temp_dir"
    exit 1
  fi

  rm -rf "$temp_dir"

  ## Symlink CLI and desktop executables
  if [[ -f "$cli_binary" ]]; then
    sudo ln -sf "$cli_binary" "$local_bin_dir/devpod"
  fi
  if [[ -f "$desktop_binary" ]]; then
    sudo ln -sf "$desktop_binary" "$local_bin_dir/devpod-desktop"
  fi

  echo "DevPod installed to $install_dir."
  echo "Symlinked 'devpod' CLI and 'devpod-desktop' GUI in $local_bin_dir."

  ## Create desktop entry
  mkdir -p "$desktop_entry_dir"
  cat > "$desktop_entry_file" <<EOF
[Desktop Entry]
Name=DevPod Desktop
Comment=DevPod Development Environment GUI
Exec=devpod-desktop
Icon=dev-pod-desktop
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
EOF

  echo "Created desktop entry at $desktop_entry_file."

  ## Copy icon files preserving directory structure
  if [[ -d "$icon_source_dir" ]]; then
    mkdir -p "$icon_target_dir"
    cp -r "$icon_source_dir/"* "$icon_target_dir/"
    echo "Copied DevPod icons to $icon_target_dir"
  else
    echo "Icon directory $icon_source_dir not found, skipping icon installation."
  fi

  echo "Installation complete. You can launch the CLI with 'devpod' and GUI with 'devpod-desktop'."
  echo "DevPod Desktop should now appear in your application launcher."
}

function uninstall_devpod {
  echo "Uninstalling DevPod..."

  ## Remove the /opt/devpod install directory
  if [[ -d "$install_dir" ]]; then
    sudo rm -rf "$install_dir"
    echo "Removed $install_dir"
  fi

  ## Remove symlinks
  sudo rm -f "$local_bin_dir/devpod"
  sudo rm -f "$local_bin_dir/devpod-desktop"
  echo "Removed symlinks in $local_bin_dir"

  ## Remove desktop entry
  if [[ -f "$desktop_entry_file" ]]; then
    rm -f "$desktop_entry_file"
    echo "Removed desktop entry at $desktop_entry_file"
  fi

  ## Remove copied icons under ~/.local/share/icons/hicolor matching DevPod icon names
  for size_dir in 16x16 32x32 48x48 64x64 128x128 256x256; do
    icon_path="$icon_target_dir/$size_dir/apps/dev-pod-desktop.png"
    if [[ -f "$icon_path" ]]; then
      rm -f "$icon_path"
      echo "Removed icon $icon_path"
    fi
  done

  echo "Uninstallation complete."
}

if [[ "$1" == "--uninstall" ]]; then
  uninstall_devpod
else
  install_devpod
fi
