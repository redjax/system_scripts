## KDE Plasma Backup <!-- omit in toc -->

Script to create `.tar.gz` archives of important Plasma configurations.

## Table of Contents <!-- omit in toc -->

- [Usage](#usage)
  - [Backup](#backup)
  - [Restore](#restore)
  - [Cron job](#cron-job)
- [Backup Targets](#backup-targets)

## Usage

See help with `./backup-kde-config.sh --help`

### Backup

```bash
backup-kde-config.sh --backup --archive-file /path/to/kde-config-backup.tar.gz
```

### Restore

```bash
backup-kde-config.sh --restore --archive-file /path/to/kde-config-backup.tar.gz
```

### Cron job

Schedule this script as a cron job (using `crontab -e`), i.e.:

```bash
  0 */6 * * * /home/$USER/backup-kde-config.sh --backup --archive-file /opt/backup/kde_plasma/kde-config-backup.tar.gz
```

Add this to the end of the crontab line to output results to a log file:

```bash
## Add >> /path/to/kde_backup.log 2>&1 to output results to a log file
0 */6 * * * /home/$USER/backup-kde-config.sh --backup --archive-file /opt/backup/kde_plasma/kde-config-backup.tar.gz >> /path/to/kde_backup.log 2>&1
```

The path for this log file must already exist, and the user must be able to write to it. You can set up logrotate to automatically rotate the log file. Create a logrotate file at `/etc/logrotate.d/kde_backup`:

```plaintext
/var/log/backup/kde_backup.log {
    size 10M
    rotate 5
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    daily
    maxage 15
    dateext
    ifempty
    create 0640 1000 1000
    sharedscripts
    postrotate
        ## You can add any post-rotate commands here if needed
        :
    endscript
}
```

## Backup Targets

The script backs up the following paths:

```
$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc
$HOME/.config/plasmarc
$HOME/.config/plasmashellrc
$HOME/.config/plasma-localerc
$HOME/.config/kdeglobals
$HOME/.config/kwinrc
$HOME/.config/kwinrulesrc
$HOME/.config/ksmserverrc
$HOME/.config/kscreenlockerrc
$HOME/.config/kactivitymanagerdrc
$HOME/.config/kactivitymanagerd-statsrc
$HOME/.config/kded5rc
$HOME/.config/kconf_updaterc
$HOME/.config/khotkeysrc
$HOME/.config/kglobalshortcutsrc
$HOME/.config/kcminputrc
$HOME/.config/kaccessrc
$HOME/.config/dolphinrc
$HOME/.config/konquerorrc
$HOME/.config/korgacrc
$HOME/.config/krunnerrc
$HOME/.config/kmixrc
$HOME/.config/ksplashrc
$HOME/.config/ktimezonedrc
$HOME/.config/powerdevilrc
$HOME/.config/powermanagementprofilesrc
$HOME/.config/discoverrc
$HOME/.config/spectaclerc
$HOME/.config/okularpartrc
$HOME/.config/kdialogrc
$HOME/.config/kiorc
$HOME/.config/kfontinstuirc
$HOME/.config/kdeconnect
$HOME/.config/KDE
```
