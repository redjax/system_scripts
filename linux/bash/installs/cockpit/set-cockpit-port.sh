#!/bin/bash

## Default port
PORT=9090

## Parse command line options
while getopts ":p:" opt; do
  case $opt in
    p)
      PORT=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

echo "Setting port for cockpit web UI to: $PORT"

## Create systemd socket drop-in directory if not exists
sudo mkdir -p /etc/systemd/system/cockpit.socket.d/

## Write the listen.conf file with the new port configuration
sudo tee /etc/systemd/system/cockpit.socket.d/listen.conf > /dev/null <<EOF
[Socket]
ListenStream=
ListenStream=$PORT
EOF

## Reload systemd and restart cockpit socket service
sudo systemctl daemon-reload
sudo systemctl restart cockpit.socket

## Detect firewall and add port
if command -v firewall-cmd >/dev/null 2>&1; then
  echo "Configuring firewalld for port $PORT/tcp"
  sudo firewall-cmd --permanent --add-port=${PORT}/tcp
  sudo firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1; then
  echo "Configuring ufw for port $PORT/tcp"
  sudo ufw allow ${PORT}/tcp
else
  echo "No recognized firewall management tool found. Please open TCP port $PORT manually if needed."
fi

## If SELinux is enabled, update the policy for new port
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" != "Disabled" ]; then
  if command -v semanage >/dev/null 2>&1; then
    echo "Configuring SELinux for port $PORT"
    sudo semanage port -m -t websm_port_t -p tcp $PORT 2>/dev/null || sudo semanage port -a -t websm_port_t -p tcp $PORT
  else
    echo "Warning: SELinux is enabled but 'semanage' command is not found. Install policycoreutils-python-utils package to manage SELinux ports."
  fi
fi

echo "Cockpit is now configured to run on port $PORT."
sudo systemctl status cockpit.socket --no-pager

