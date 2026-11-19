# ClamAV Scripts

Install ClamAV, configure database access, update signatures, and run on-demand malware scans.

The main entry point script is `scan.sh`.

## Scripts

| Script                | Purpose                                                                            |
| --------------------- | ---------------------------------------------------------------------------------- |
| `install.sh`          | Install ClamAV and invoke database/security-policy configuration.                  |
| `configure.sh`        | Prepare the database directory and configure recognized AppArmor/SELinux policies. |
| `freshclam-update.sh` | Download or update malware signatures.                                             |
| `scan.sh`             | Scan configurable targets and save per-run reports.                                |
| `full-scan.sh`        | Run `scan.sh` against `/` with platform-specific exclusions.                       |
| `run-clam-scan.sh`    | Compatibility wrapper for `scan.sh`; optional if nothing references it.            |
| `tail-clamav-logs.sh` | Follow a specified report file or systemd journal unit.                            |
| `lib.sh`              | Shared helper functions.                                                           |

## Installation

Run as your normal user. The installer elevates Linux operations when required.

```bash
./install.sh --dry-run
./install.sh
./freshclam-update.sh
```

Supported package managers: APT, DNF, YUM, Pacman, APK, Zypper, and Homebrew. Package availability depends on enabled repositories and distribution release.

The setup does not automatically enable repositories or disable security controls. Unrecognized policy layouts and missing dependencies produce errors.

## Database Location

Default:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db
```

This database is separate from a system-managed ClamAV database. For SELinux-enabled systems, use a dedicated system-state directory:

```bash
./install.sh \
  --database /var/lib/security-scans/clamav/db \
  --owner "$(id -un)"

./freshclam-update.sh \
  --database /var/lib/security-scans/clamav/db
```

Use the same `--database` path for installation, updates, and scans. When running `configure.sh` directly through `sudo`, specify both the database and its intended owner:

```bash
sudo ./configure.sh \
  --database /home/jack/.cache/security-scans/clamav/db \
  --owner jack
```

## Scanning

Update signatures before scanning:

```bash
./freshclam-update.sh
```

Scan selected directories:

```bash
./scan.sh \
  --target "$HOME/Downloads" \
  --target "$HOME/projects" \
  --exclude-dir '(^|/)(node_modules|\.git)(/|$)'
```

Without a target, `scan.sh` scans the current directory recursively.

Preview a full-machine scan:

```bash
./full-scan.sh --dry-run
```

Run a full-machine scan with an explicit database path:

```bash
sudo ./full-scan.sh \
  --database /home/jack/.cache/security-scans/clamav/db \
  --output-dir /var/log/security-scans/clamav
```

Replace the example database path with your configured location. Using `sudo` can change the default home/cache directory.

> [!TIP]
> Run any script with `--help` for its options.

## Reports and Exit Codes

Reports default to a unique directory beneath `./clamav-reports/`:

- `command.txt`: executed scan command.
- `metadata.txt`: platform, database, and version information.
- `output.log`: scanner output and errors.
- `result.tsv`: result and native exit statuses.

Follow a report:

```bash
./tail-clamav-logs.sh --log-file /path/to/run-directory/output.log
```

Scanner exit codes:

| Code | Meaning                                                  |
| ---- | -------------------------------------------------------- |
| `0`  | No malware detected by the completed scan.               |
| `1`  | Malware detected.                                        |
| `2`  | Argument, dependency, scanning, or report-writing error. |

## Safety and Limitations

- Scans do not automatically update signatures, delete files, or quarantine findings.
- Exclusions use regular expressions.
- Permissions, exclusions, filesystem boundaries, and scan limits affect coverage.
- A scan reporting no detections does not prove the machine is uncompromised.
- Do not share a database directory with another concurrently running updater.
