#!/bin/bash

## Fix issue with monitors going to sleep & waking up on a cycle
#  when using KDE Plasma.

xset -dpms
gdbus monitor --system -y -d org.freedesktop.login1 | while read -r line; do
    if [[ "$line" == *"LockedHint': <true>"* ]]; then
        xset +dpms
    elif [[ "$line" == *"LockedHint': <false>"* ]]; then
        xset -dpms
    fi
done

