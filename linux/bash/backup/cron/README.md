# Cron Backup

`crontab` is a task scheduler for Unix systems, which can call commands or scripts on an interval. It is relatively simple, highly configurable, and very flexible.

## List cron jobs

- List current user's crontab:

```bash
crontab -l
```

- List a specific user's crontab:

```bash
sudo crontab -l -u $USERNAME
```

- List the root crontab:

```bash
sudo crontab -l -u root
```

## Backup Cron

You can use one of the [crontab list commands](#list-cron-jobs) and output the text to a file to create a backup. For example: `crontab -l ~/crontab_backup.txt`.

You can backup another user's crontab similarly, passing the `-u` parameter, like: `sudo crontab -l -u $USERNAME > /path/to/cron/backup`.

### Automated

You can use `cron` to schedule backups of itself! Just add this job:

```bash
## Backup crontab at midnight
0 0 * * * crontab -l > /path/to/backup/crontab_$(date +\%F).txt
```

## Restore

Restoring a crontab is as easy as running `crontab /path/to/cron/backup`. Similarly, to restore another user's crontab, run `sudo crontab /path/to/cron/backup -u $USERNAME`

