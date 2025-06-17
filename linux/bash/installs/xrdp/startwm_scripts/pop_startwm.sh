#!/bin/sh

## Pop OS shell XRDP session.
#  Copy to /etc/xrdp/startwm.sh

export GNOME_SHELL_SESSION_MODE=pop
export GDMSESSION=pop
export XDG_CURRENT_DESKTOP=pop:GNOME
exec gnome-session