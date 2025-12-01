# ClamAV <!-- omit in toc -->

[ClamAV](https://www.clamav.net) is an open source antivirus.

## Table of Contents <!-- omit in toc -->

- [Notes](#notes)
  - [Enable freshclam daemon](#enable-freshclam-daemon)
- [Links](#links)

## Notes

### Enable freshclam daemon

Configure automatic signature updates by creating service file for systemd.

- Locate `freshclam.conf` (normally at `/etc/clamav/freshclam.conf` or `/etc/freshclam.conf`).
  - Before doing anything, make a backup, i.e. `cp /etc/freshclam.conf /etc/freshclam.conf.orig`
  - Find the line that says `Example` and add a `#` to it so it becomes `#Example`
    - You can also run `sed -i 's/^Example/#Example/' /etc/clamav/freshclam.conf` to do this
  - Find the `#Checks 24` line.
    - Uncomment it and optionally change the value.
    - The value represents how many times per day freshclam should update.
    - `24` = once per hour
  - Append `LogFile /var/log/clamav/freshclam.log` to tell it where to save logs.
    - Create `/var/log/clamav` with `sudo mkdir -p /var/log/clamav`
    - Set the owner with `sudo chown -R clamav:clamav /var/log/clamav`
- Enable the service with `sudo systemctl enable --now clamav-freshclam`

You can also use the [example `freshclam.conf`](./freshclam.conf).

## Links

- [ClamAV docs](https://docs.clamav.net/manual/Usage.html)
- [Gist: AntoOnline/ClamAV Cheat Sheet](https://gist.github.com/AntoOnline/83d0c1e419341aaf5e3652b2bb438457)
- [softhandtech: Mastering ClamAV](https://softhandtech.com/how-do-i-install-and-run-clamav/)
