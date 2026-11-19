# rkhunter Scripts

Install Rootkit Hunter, validate its configuration, update detection data, and run host-level security checks.

> [!NOTE]
> This adapter currently supports Linux only. It uses rkhunter's installed configuration and database locations.

## Scripts

| Script                      | Purpose                                                        |
| --------------------------- | -------------------------------------------------------------- |
| `install.sh`                | Install rkhunter and validate its configuration.               |
| `configure.sh`              | Validate the existing configuration without changing settings. |
| `enable-network-updates.sh` | Explicitly enable upstream data downloads using wget.          |
| `update.sh`                 | Update detection/support data, not the trusted baseline.       |
| `baseline.sh`               | Explicitly trust current tracked file properties.              |
| `scan.sh`                   | Run host checks and save reports.                              |
| `lib.sh`                    | Shared argument parsing, execution, locking, and reporting.    |

## Installation

Run the installer as your normal user. It elevates installation and configuration validation when necessary.

```bash
./install.sh --dry-run
./install.sh
```

Supported package managers:

- APT
- DNF / YUM
- Zypper
- Pacman
- APK

> [!NOTE]
> Package availability depends on the distribution release and enabled repositories. The installer does not enable additional repositories. Installation does not request detection-data updates or baseline creation. Distribution package hooks remain outside the wrapper's control.

## Configuration

Validate the installed configuration:

```bash
sudo ./configure.sh --verbose
```

Validate an alternate main configuration:

```bash
sudo ./configure.sh \
  --config /path/to/rkhunter.conf \
  --verbose
```

Use the same `--config` option for subsequent updates, scans, and baseline operations when selecting an alternate configuration. Validation checks settings relevant to currently enabled tests. It does not establish that the machine is trustworthy.

## Network Updates

Some packaged configurations disable upstream downloads through settings such as `WEB_CMD="/bin/false"`.

For the standard `/etc/rkhunter.conf` layout, explicitly enable downloads:

```bash
sudo ./enable-network-updates.sh --dry-run
sudo ./enable-network-updates.sh
```

The helper requires wget and configures:

```text
WEB_CMD=wget
UPDATE_MIRRORS=1
MIRRORS_MODE=0
```

It backs up the main configuration and restores its contents if validation fails. It refuses to proceed when recognized local override files define conflicting update settings. The helper does not support alternate main configuration paths.

Update detection/support data:

```bash
sudo ./update.sh --verbose
```

> [!NOTE]
> This does not upgrade the installed program or refresh trusted file properties. Obtain program upgrades through the package manager.

## Run a Scan

Run the configured host checks:

```bash
sudo ./scan.sh --verbose
```

For quieter terminal output:

```bash
sudo ./scan.sh
```

Scans inspect the running host, and do not automatically update detection data or the baseline.

Preview the command without running checks or writing reports:

```bash
./scan.sh --dry-run
```

Choose a report location:

```bash
sudo ./scan.sh \
  --output-dir /var/log/security-scans/rkhunter \
  --verbose
```

List available rkhunter tests:

```bash
sudo rkhunter --list tests
```

Select particular tests:

```bash
sudo ./scan.sh --enable rootkits --verbose
```

Selecting or disabling tests changes coverage. The installed configuration also affects which checks run.

## Review Warnings Before Accepting a Baseline

A `review-required` result means rkhunter returned nonzero. It does not distinguish malware findings from configuration errors or other warnings.

Inspect the actual findings in the reported run directory:

```bash
LOG=/var/log/security-scans/rkhunter/scan.XXXXXXXX/rkhunter.log

sudo grep -nEi -B 3 -A 6 \
  'warning:|\[ warning \]|error:|prerequisites' \
  "$LOG"
```

Read the full log when the surrounding context is insufficient:

```bash
sudo less "$LOG"
```

> [!WARNING]
> Investigate each finding. Do not suppress warnings or refresh the baseline solely to obtain a successful result.

## Trusted Baseline

The baseline stores properties of tracked system files. Only after verifying those files are genuine and trustworthy:

```bash
sudo ./baseline.sh --accept-current-state --verbose
```

Then scan again:

```bash
sudo ./scan.sh --verbose
```

> [!IMPORTANT]
> - Baseline creation does not clean or repair the machine.
> - It accepts current tracked file properties as trusted.
> - It does not resolve every kind of warning.
> - Do not automatically refresh it before each scan.
> - Investigate changed files before accepting a refreshed baseline.
>
> The wrapper updates the complete configured file-properties baseline; it does not expose partial file or package baseline updates.

## Reports

Operations create unique directories beneath:

```text
/var/log/security-scans/rkhunter/
```

Example:

```text
scan.XXXXXXXX/
├── command.txt
├── metadata.txt
├── output.log
├── rkhunter.log
└── result.tsv
```

| File           | Contents                                                           |
| -------------- | ------------------------------------------------------------------ |
| `command.txt`  | Executed command.                                                  |
| `metadata.txt` | Action, start time, platform, version, and selected configuration. |
| `output.log`   | Captured terminal output.                                          |
| `rkhunter.log` | Detailed native log, if execution creates it.                      |
| `result.tsv`   | Action, summarized status, and native exit codes.                  |

Without `--verbose`, full terminal output is still saved to `output.log`.

## Exit Codes

### Scanning

| Code | Meaning                                                         |
| ---- | --------------------------------------------------------------- |
| `0`  | rkhunter returned success.                                      |
| `2`  | Wrapper, dependency, setup, or detected report-writing failure. |
| `3`  | rkhunter returned nonzero; review warnings or errors.           |

### Configuration and Baseline Operations

| Code | Meaning                       |
| ---- | ----------------------------- |
| `0`  | Operation succeeded.          |
| `2`  | Operation or wrapper failure. |

### Detection-Data Updates

| Code | Meaning                                     |
| ---- | ------------------------------------------- |
| `0`  | Update succeeded or no updates were needed. |
| `2`  | Update or wrapper failure.                  |

For updates, native rkhunter code `2` means updates were installed successfully. The wrapper normalizes this to success and preserves the native code in `result.tsv`.

## Locking

The wrappers coordinate through:

```text
/run/security-scans-rkhunter.lock
```

An existing lock prevents another wrapper operation from starting.

> [!NOTE]
> This does not coordinate independent distribution jobs or direct rkhunter invocations. If a lock appears stale, verify that no wrapper operation is still running before removing it.

## Limitations

- A successful scan does not prove the host is uncompromised.
- Warnings require investigation; they are not automatically malware.
- No automatic remediation, allowlisting, or baseline acceptance occurs.
- Network-update configuration is an explicit policy change.
- Package-manager and policy behavior can vary between distributions.
- Run any script with `--help` for its supported options.
