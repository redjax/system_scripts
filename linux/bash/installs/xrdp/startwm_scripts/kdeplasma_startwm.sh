#!/bin/sh

## KDE Plasma XRDP session.
#  Copy to /etc/xrdp/startwm.sh

export KDE_FULL_SESSION=true
export XDG_CURRENT_DESKTOP=KDE
exec startplasma-x11
