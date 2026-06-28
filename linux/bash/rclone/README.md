# Rclone Scripts

[Rclone](https://rclone.org) is a CLI tool for managing files in cloud storage (or over SSH).

## Caller Script

You can write a calling script that passes values into this script, which can be useful for passing sensitive values like tokens and keys.

```shell
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="/path/to/system_scripts/linux/bash/rclone/rclone-s3-sync.sh"
## Change `YOUR_USERNAME` to your actual username. Hardcoding the path
#  to your rclone config ensures it works even when run with sudo.
RCLONE_CONF="/home/YOUR_USERNAME/.config/rclone/rclone.conf"

RCLONE_LOCAL_REPO="/path/to/your/restic/repository"

## Name of remote config in your rclone.conf file
RCLONE_REMOTE_NAME="some-remote-name"
RCLONE_REMOTE_BUCKET_NAME="some-bucket-name"
## Directory path inside s3 bucket where data is/should be
RCLONE_BUCKET_PATH="path/in/bucket"
## Bandwidth limit. Can be a single value, i.e. 10M,
#  or a schedule, i.e. 08:00,5M 23:00,15M
RCLONE_BW_LIMIT="08:00,5M 23:00,15M"

DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    *)
      echo "[ERROR] Invalid arg: ${1}" >&2
      exit 1
      ;;
  esac
done

echo "[DEBUG] Home: ${HOME_PATH}"
echo "[DEBUG] Script path: ${SCRIPT_PATH}"

echo "Starting rclone backup of Restic repository to Wasabi"

cmd=("${SCRIPT_PATH}" --config "${RCLONE_CONF}" --local-path "${RCLONE_LOCAL_REPO}" --remote-name "${RCLONE_REMOTE_NAME}" --bucket-name "${RCLONE_REMOTE_BUCKET_NAME}" --bucket-path "${RCLONE_BUCKET_PATH}" --transfers 2 --checkers 4 --bwlimit "${RCLONE_BW_LIMIT}")

if [[ "${DRY_RUN}" == "true" ]]; then
  cmd+=(--dry-run)
fi

echo "[DEBUG] Command:"
echo "  ${cmd[*]}"

"${cmd[@]}"

```

## Crontab

You can set a cron job to run a clone on a schedule. Because of the way `rclone` works, only changes will be synchronized/copied.

Option 1: raw shell command

```shell
## Every night at 4:30am
30 4 * * * rclone --config /home/username/.config/rclone/rclone.conf --local-path /path/to/restic/repo --remote-name rclone-remote-name --bucket-name s3-bucket-name --bucket-path path/in/bucket --transfers 2 --checkers 4 --bwlimit 15M 
```

Option 2: [caller script](#caller-script)

```shell
## Run the script that calls the rclone-s3-sync.sh script.
#  Optionally log to a file
30 4 * * * /bin/bash /path/to/caller-script.sh >> /var/log/restic/rclone-cron-nightly.log 2>&1
```

If you outuput to a log file, the directory path must exist:

```shell
sudo mkdir -p /var/log/restic
sudo chmod $USER:$USER /var/log/restic
```

And you should create a logrotate config to keep the file from becoming too large. Create a file like `/etc/logrotate.d/rclone-cron-nightly`:

```plaintext
/var/log/restic/rclone-cron-nightly.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate

```

## Links

- [Rclone home](https://rclone.org)
- [Rclone docs](https://rclone.org/docs/)
- [Rclone providers](https://rclone.org/overview/)
- [Rclone commands](https://rclone.org/commands/)

