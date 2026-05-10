# Fix Keychron Webapp Permission

Keychron keyboards can be configured on the [Keychron launcher site](https://launcher.keycron.com) or the [VIA webapp](https://usevia.app). Note that these are only compatible/usable with Chromium browsers as of 2026-05-09.

When you attempt to connect, the browser might show a message like:

```plaintext
HID Device Connected [K]
```

If it has a red x in a circle, the connection actually failed, despite what the message says.

## Fix 1 - udev rule

Create a file at `/etc/udev/rules.d/99-keychron.rules` with the following:

```plaintext
KERNEL=="hidraw*", ATTRS{idVendor}=="3434", MODE="0666"
```

You can also copy the [included keychron rules file](./99-keychron.rules):

```shell
sudo cp ./99-keychron.rules /etc/udev/rules.d/99-keychron.rules
```

Reload udev rules:

```shell
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Fix 2 - Manual chmod

Navigate to [chrome:device-log](chrome:devie-log) in your browser. Use CTRL+F to search for a message like:

```plaintext
Failed to open '/dev/hidraw3': FILE_ERROR_ACCESS_DENIED
```

Make note of the `/dev/hidraw#` path; it will not always be `3`. When you run the script, provide it with `--device /dev/hidraw#`, where `#` is the number you see.

> [!WARNING] Security note
> The script has 2 modes: `--allow` and `--deny`. Make sure to always run `--deny` after an allow command.
>
> Running `--allow` gives world-readable permissions, which is insecure. Running `--deny` sets the chmod back to `600`.

```shell
./set-udev-permissions.sh --device /dev/hidraw{num} --allow

## When you're finished configuring the keyboard
./set-udev-permissions.sh --device /dev/hidraw{num} --deny
```

