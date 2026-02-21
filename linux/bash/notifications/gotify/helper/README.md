# Gotify Notification Helper

Helper script for [Gotify](https://gotify.net) notifications using cURL.

Call this script directly, or as part of another command.

## Usage

*Run `./gotify-notification-helper.sh -h` to see all options*

Send a notification from the CLI:

```shell
./gotify-notification-helper.sh \
  -u https://gotify.example.com \
  -T ABC123 \
  -t "Example notification title" \
  -m "This is an example message from $(hostname) at $(date)" \
  -p 8
```

Or as part of a cron job:

```shell
0 2 * * * /path/to/some/script.sh >/dev/null 2>&1 || \
  /usr/local/bin/gotify-notify \
  -u https://gotify.example.com \
  -f /root/.secrets/gotify_token \
  -t "Script Failed" \
  -m "Script failed on $(hostname) at $(date)" \
  -p 8
```


Or after another command:

```shell
./some-script.sh || /path/to/gotify-notification-helper.sh -u https://gotify.example.one -f /path/to/gotify-token-file -t "Script failed" -m "The some-script.sh script failed on host $(hostname) at $(date)" -p 5
```
