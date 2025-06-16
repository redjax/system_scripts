#!/bin/bash

##
# On machines with multiple monitors, this script
# uses your display configuration for the login
# screen,too
##

##

echo "Setting login display settings the same as logged-in session"
sudo cp ~/.config/monitors.xml ~gdm/.config/
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to set login screen settings."
  exit $?
else
  echo "Successfully updated login windows settings"
  exit 0
fi


