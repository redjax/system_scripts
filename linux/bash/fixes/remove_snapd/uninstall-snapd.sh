#!/bin/bash

if ! command -v snap &>/dev/null; then
  echo "Snap is not installed."
  exit 0
fi

echo "Listing all installed Snap packages..."
snaps=$(snap list --all | awk 'NR>1 {print $1}' | grep -v "^core$" || true)
if [ -n "$snaps" ]; then
    echo "Removing all Snap packages..."
    
    for pkg in $snaps; do
        sudo snap remove --purge "$pkg"
    done

else
    echo "No Snap packages found."
fi

echo "Disabling Snapd systemd services..."
sudo systemctl disable --now snapd.service snapd.socket snapd.seeded.service || true

echo "Purging snapd..."
sudo apt-get purge --yes snapd

echo "Removing leftover Snap data/directories..."
rm -rf ~/snap
sudo rm -rf /snap \
  /var/snap \
  /var/lib/snapd \
  /var/cache/snapd

if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed uninstalling snapd"
  exit $?
else
  echo "Snap has been completely removed! It is recommended to reboot your system."
fi

