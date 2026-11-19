# Maldet Scripts

Install Linux Malware Detect (LMD) and run report-only malware scans.

This adapter targets upstream LMD on Linux using the standard `/usr/local/maldetect` installation layout.

## Files

| Script       | Purpose                                                     |
| ------------ | ----------------------------------------------------------- |
| `install.sh` | Run a reviewed upstream installer with explicit acceptance. |
| `update.sh`  | Update detection signatures.                                |
| `scan.sh`    | Scan one target with report-only runtime settings.          |
| `lib.sh`     | Shared helpers and configuration checks.                    |

## Installation

Obtain and review an upstream LMD source tree. Pin the selected release/commit in your deployment process.

Preview:

```bash
./install.sh --source-dir /path/to/reviewed/lmd-source --dry-run
```

Install:

```bash
sudo ./install.sh \
  --source-dir /path/to/reviewed/lmd-source \
  --accept-upstream-install
```

The wrapper does not download source or install dependencies. The source tree must remain trusted and unchanged while the installer runs.

## Upstream Installer Effects

The upstream installer is not limited to on-demand CLI setup. It can:

- Install under /usr/local/maldetect.
- Install cron jobs and service integration.
- Enable the Maldet service.
- Download signatures.
- Deploy LMD signatures into standard ClamAV directories.
- Signal clamd to reload.

Review these integrations after installation. The wrapper does not disable or manage independent scheduled jobs or monitoring. Do not assume the scan wrapper's report-only overrides apply to cron jobs, monitors, direct maldet commands, or third-party integrations.

## Signature Updates

```bash
sudo ./update.sh --verbose
```

This invokes the signature updater, not the program self-updater. Signature updates may refresh integrated signatures in standard ClamAV
database directories.

## Scan

```bash
sudo ./scan.sh --target /var/www --verbose
```

Preview:

```bash
./scan.sh --target "$HOME/projects" --dry-run
```

Scan recent changes:

```bash
sudo ./scan.sh \
  --target /srv \
  --recent-days 7 \
  --verbose
```

Increase the file-size limit:

```bash
sudo ./scan.sh \
  --target /var/www \
  --max-filesize-kb 10240 \
  --max-depth 40 \
  --verbose
```

Targets are literal paths. One target is supported per invocation.

## Engines

Native LMD scanning is the default:

```bash
sudo ./scan.sh --target /var/www --engine native
```

ClamAV integration is opt-in:

```bash
sudo ./scan.sh --target /var/www --engine clamav --verbose
```

This does not automatically select the private database configured for the separate ClamAV wrapper. Review Maldet's output for its selected engine and database behavior.

## Report-Only Behavior

Scan runtime settings disable:

- Automatic quarantine.
- Cleaning.
- User suspension.
- Quarantine on engine errors.
- Built-in email, Slack, Telegram, and Discord alerts.

Root-owned files are included. The wrapper rejects recognizable nonempty remote-configuration imports and post-scan hooks in the standard configuration files. The installed executable, libraries, and configuration remain trusted root-executed software.

Existing ignore files, ownership filters other than scan_ignore_root, optional engines, and other installed settings can still affect coverage. LMD may also include configured temporary paths beyond the requested target.

## Reports

Default parent directory:

```text
/var/log/security-scans/maldet/
```

Scan wrapper reports include:

```text
scan.XXXXXXXX/
├── command.txt
├── metadata.txt
├── version.txt
├── output.log
└── result.tsv
```

Maldet also retains native session reports.

Use the SCANID printed by the scan:

```bash
sudo maldet --report SCANID
```

Prefer an explicit SCANID rather than "latest" when other scans may run concurrently.

## Exit Codes

### Scans

| Wrapper code | Meaning                                      |
| ------------ | -------------------------------------------- |
| `0`          | Native scan reported success with no hits.   |
| `1`          | Native scan reported malware hits.           |
| `2`          | Native scan error or wrapper/report failure. |

Native Maldet hit code 2 is normalized to wrapper code 1. The original status is retained in result.tsv.

### Signature Updates

| Wrapper code | Meaning                           |
| ------------ | --------------------------------- |
| `0`          | Native updater returned success.  |
| `2`          | Update or wrapper/report failure. |

## Limitations

- Linux only
- Read scanned-file counts and skipped-file messages.
- Size limits, traversal depth, ignore rules, and configured filters affect coverage.
- Reported hits require investigation.
- No detections does not prove the target is malware-free.
- Independent automatic jobs are outside the wrapper's report-only policy.
- Use `--help` for all supported options.
