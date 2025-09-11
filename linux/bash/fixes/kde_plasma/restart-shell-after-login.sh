#!/bin/bash

## Sometimes after logging back into KDE, especially after the machine goes to sleep,
#  the shell is not restarted. This script forces the shell to restart.

## Check if KDE Plasma desktop session is running
if [[ "$XDG_CURRENT_DESKTOP" != *KDE* ]] && [[ "$DESKTOP_SESSION" != *plasma* ]]; then
  echo "KDE Plasma does not appear to be running on this session."
  exit 1
fi

## Check if kstart command is available
if ! command -v kstart &> /dev/null; then
  echo "kstart not found. Please ensure KDE and kstart are installed."
  exit 2
fi

## Try kstart plasmashell first
echo "Attempting to run: kstart plasmashell"
kstart plasmashell

## Prompt user to check if the issue is fixed
while true; do
  read -p "Did running 'kstart plasmashell' fix the panel issue? (yes/no): " yn
  case $yn in
    [Yy]* ) echo "Exiting script."; exit 0;;
    [Nn]* )  break;;
    * )   echo "Please answer yes or no.";;
  esac
done

## Fallback: killall plasmashell && kstart plasmashell
echo "Trying fallback: killall plasmashell && kstart plasmashell"

killall plasmashell
sleep 1
kstart plasmashell

echo "Fallback executed: killall plasmashell && kstart plasmashell"

## Prompt user to check if the issue is fixed
while true; do
  read -p "Did running 'killall plasmashell && kstart plasmashell' fix the panel issue? (yes/no): " yn

  case $yn in
    [Yy]* ) echo "Exiting script."; exit 0;;
    [Nn]* )  break;;
    * )   echo "Please answer yes or no.";;
  esac
done

echo "Unable to fix the issue. If Plasma shell has not started yet, it may soon, otherwise you should reboot to resolve the issue."
