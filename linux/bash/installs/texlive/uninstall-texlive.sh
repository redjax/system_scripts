#!/usr/bin/env bash

echo "[ TeX Live Full Uninstall ]"

## Find all TeX Live installations
echo "Scanning for TeX Live installations"
TEX_INSTALLED=$(tlmgr info --list-paths | grep -E '^/usr/local/texlive/[0-9]{4}' || find /usr/local/texlive -maxdepth 1 -type d 2>/dev/null)

if [ -z "$TEX_INSTALLED" ]; then
  echo "[ERROR] No full TeX Live installation found."
  exit 1
fi

echo "Found installations:"
echo "$TEX_INSTALLED"

echo -n "Remove all TeX Live installs? [y/N]: "
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

## Remove installations
for install in $TEX_INSTALLED; do
  if [ -d "$install" ]; then
    echo "Removing $install"
    sudo rm -rf "$install"
  fi
done

## Clean up PATH from shell profiles
for profile in ~/.bashrc ~/.zshrc ~/.bash_profile; do
  if [ -f "$profile" ] && grep -q "texlive" "$profile" 2>/dev/null; then
    echo "Cleaning $profile"
    sudo sed -i '/texlive.*PATH/d' "$profile"
  fi
done

echo "Full TeX Live uninstalled. Run 'hash -r' or restart shell."
