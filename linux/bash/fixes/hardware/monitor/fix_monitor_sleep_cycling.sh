#!/bin/bash

## If you are using X11 and your monitors continuously cycle between off and searching/on,
#  try this script to suppress that behavior.
#
#  NOTE: This is for AMD graphics

if [[ ! -d /etc/X11/xorg.conf.d ]]; then
  sudo mkdir -p /etc/X11/xorg.conf.d
fi

function create_monitor_config {
  ## Write global server flags
  cat <<EOF | sudo tee -a /etc/X11/xorg.conf.d/10-monitor.conf
Section "ServerFlags"
    Option "DontZap" "True"  # Prevent Ctrl+Alt+Backspace from terminating the X session
    Option "BlankTime" "0"   # Disable screen blanking
EndSection
EOF

  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to write global server flags to /etc/X11/xorg.conf.d/10-monitor.conf"
    return 1
  fi

  ## Get list of connected monitors using xrandr
  connected_monitors=$(xrandr --listmonitors | awk '{print $NF}')
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to get list of connected monitors"
    return 1
  fi

  ## Loop through each connected monitor and add it to the config
  for monitor in $connected_monitors; do
    cat <<EOF | sudo tee -a /etc/X11/xorg.conf.d/10-monitor.conf
Section "Monitor"
    Identifier "$monitor"
    Option "DPMS" "false"  # Disable DPMS (Display Power Management Signaling)
EndSection
EOF

    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to write monitor config for $monitor to /etc/X11/xorg.conf.d/10-monitor.conf"
        return 1
    fi
  done
}

function main {
    if [[ ! -f /etc/X11/xorg.conf.d/10-monitor.conf ]]; then
      echo "Creating monitor configuration at /etc/X11/xorg.conf.d/10-monitor.conf"
    
      create_monitor_config
      if [[ $? -ne 0 ]]; then
          echo "[ERROR] Failed to create monitor configuration"
          return 1
      else
          echo "Configuration file created successfully."
          return 0
      fi

    else
      echo "Monitor configuration already exists at /etc/X11/xorg.conf.d/10-monitor.conf"
      read -p "Do you want to overwrite the existing configuration? (y/n): " overwrite

      if [[ $overwrite == "y" || $overwrite == "Y" || $overwrite == "yes" || $overwrite == "Yes" ]]; then
        sudo cp /etc/X11/xorg.conf.d/10-monitor.conf /etc/X11/xorg.conf.d/10-monitor.conf.bak

        create_monitor_config
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to create monitor configuration"
            return 1
        else
            echo "Configuration file overwritten successfully."
            return 0
        fi

      else
        echo "Configuration file was not overwritten."
        return 0
      fi
    fi
}

if [[ $BASH_SOURCE = "$0" ]]; then
    main "$@"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to configure monitor(s)"
        exit 1
    else
        echo "Successfully configured monitor(s)"
        exit 0
    fi
fi
