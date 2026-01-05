#!/bin/bash

## Sometimes after logging back into KDE, especially after the machine goes to sleep,
#  the shell is not restarted. This script forces the shell to restart.

echo ""
echo "Attempting to reset the plasma-plasmashell.service systemd unit"

pkill -KILL plasmashell
systemctl --user reset-failed plasma-plasmashell.service
systemctl --user start plasma-plasmashell.service

echo "Sleeping for 3 seconds..."
sleep 3

## Prompt user again to check if problem is fixed
while true; do
  read -n 1 -r -p "Did resetting the systemd unit fix the issue? (y/n): " yn
  echo ""

  case $yn in
  [Yy])
    echo ""
    echo "Exiting script."
    exit 0
    ;;
  [Nn])
    break
    ;;
  esac
done

## Check if kstart command is available
if ! command -v kstart &>/dev/null; then
  echo "kstart not found. Please ensure KDE and kstart are installed."
  exit 2
fi

## Check if KDE Plasma desktop session is running
if [[ "$XDG_CURRENT_DESKTOP" != *KDE* ]] && [[ "$DESKTOP_SESSION" != *plasma* ]]; then
  echo "KDE Plasma does not appear to be running on this session."

  read -p "Do you want to start Plasma? (yes/no): " yn

  case $yn in
  [Yy]*)
    echo "Starting plasma server with 'kstart plasma shell'"
    kstart plasmashell

    sleep 3

    read -n 1 -r -p "Did Plasma start? (yes/no): " yn
    case $yn in
    [Yy]*)
      exit 0
      ;;
    [Nn]*)
      echo "You may need to log out/back in, or restart your machine."
      exit 1
      ;;
    *)
      echo "Please answer 'yes' or 'no'"
      ;;
    esac
    ;;

  [Nn]*)
    exit 0
    ;;
  *)
    echo "Please answer yes or no."
    ;;
  esac

  exit 1
fi

## Try kstart plasmashell first
echo "Running 'kstart plasmashell' and waiting 5 seconds..."
kstart plasmashell

sleep 5

## Prompt user to check if the issue is fixed
while true; do
  read -n 1 -r -p "Did running 'kstart plasmashell' fix the panel issue? (yes/no): " yn
  case $yn in
  [Yy]*)
    echo ""
    echo "Exiting script."
    exit 0
    ;;
  [Nn]*) break ;;
  *) echo "Please answer yes or no." ;;
  esac
done

## Fallback: killall plasmashell && kstart plasmashell
echo ""
echo "Trying fallback: killall plasmashell && kstart plasmashell"

killall plasmashell
sleep 1
kstart plasmashell

echo "Fallback executed: killall plasmashell && kstart plasmashell"
echo "Pausing for 3 seconds..."

sleep 3

## Prompt user to check if the issue is fixed
while true; do
  read -n 1 -r -p "Did running 'killall plasmashell && kstart plasmashell' fix the panel issue? (yes/no): " yn

  case $yn in
  [Yy]*)
    echo ""
    echo "Exiting script."
    exit 0
    ;;
  [Nn]*) break ;;
  *) echo "Please answer yes or no." ;;
  esac
done

echo ""
echo "Unable to fix the issue. If Plasma shell has not started yet, it may soon, otherwise you should reboot to resolve the issue."
