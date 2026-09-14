# Flemozi Emoji Picker

[Flemozi](https://github.com/KRTirtho/flemozi) is an "advanced emoji picker" for Windows, Mac, and Linux. It can search GIFs, stickers, and ASCII emoji, and copy them to the clipboard for pasting.

## Troubleshooting

### Shortcut doesn't open emoji picker

On Linux Wayland, you may run into an issue where a shortcut like `Super+.` inserts an `e` and keypresses stop working until you hit `ESC`. This happens when the IBus emoji input mode intercepts the shortcut. I have run into this on Fedora Linux running GNOME.

You can fix this by disabling the global shortcut. Check what IBus currently has configured:

```shell
gsettings get org.freedesktop.ibus.panel.emoji hotkey
```

You should see something like `['<Super>period', '<Super>semicolon']`. If you see this, you can unset the key with:

```shell
gsettings set org.freedesktop.ibus.panel.emoji hotkey "[]"
```

> [!NOTE]
> You can revert this by doing the inverse, running:
>
> ```shell
> gsettings set org.freedesktop.ibus.panel.emoji hotkey "['<Super>period', '<Super>semicolon']"
> ```

Then log out and back in to apply it, or run:

```shell
ibus restart
```

You can check what is bound to `Super+.` with:

```shell
gsettings list-recursively | grep -i 'super.*period'
```
