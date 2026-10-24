# Lynis Scripts

Install Lynis and run host-security audits on Linux and macOS. Lynis audits configuration and hardening opportunities. Findings are not automatically malware detections.

## Files

| Script       | Purpose                                                     |
| ------------ | ----------------------------------------------------------- |
| `install.sh` | Install Lynis using an available supported package manager. |
| `scan.sh`    | Run a host audit and save per-run reports.                  |
| `lib.sh`     | Shared helper functions.                                    |

There is no baseline acceptance or malware-definition updater. Update Lynis through its installation method.

## Installation

Run as your normal user:

```bash
./install.sh --dry-run
./install.sh
```

Supported installation paths:

- Linux: APT, DNF, YUM, Zypper, Pacman, APK.
- macOS: Homebrew.

Package availability depends on enabled repositories and distribution release. The installer does not add repositories or install Homebrew.

## Audit

Preview:

```bash
./scan.sh --dry-run
```

Run and display native output:

```bash
sudo ./scan.sh --verbose
```

Without `--verbose`, full terminal output is still saved.

The adapter disables pauses between sections. It does not automatically reduce the audit's scope.

## macOS and Homebrew

Resolve the executable before invoking sudo:

```bash
LYNIS_BIN="$(command -v lynis)"

sudo ./scan.sh \
  --lynis-bin "$LYNIS_BIN" \
  --verbose
```

Use only a trusted Lynis installation when running it with root privileges.

## Profiles and Test Selection

Use an alternate profile:

```bash
sudo ./scan.sh \
  --profile /path/to/custom.prf \
  --verbose
```

Run selected tests:

```bash
sudo ./scan.sh \
  --test SSH-7408 \
  --test AUTH-9286 \
  --verbose
```

Run a category:

```bash
sudo ./scan.sh --category authentication --verbose
```

Use test IDs and category names supported by the installed Lynis version.

The wrapper does not allow combining `--test` with `--category`. Profiles and test selection affect coverage. Use trusted profiles for privileged audits.

## Reports

Default parent directory:

```text
/var/log/security-scans/lynis/
```

Override it:

```bash
sudo ./scan.sh \
  --output-dir /var/log/security-scans/lynis \
  --verbose
```

Each run creates a unique directory:

```text
scan.XXXXXXXX/
├── command.txt
├── metadata.txt
├── version.txt
├── output.log
├── lynis.log
├── lynis-report.dat
├── findings.txt
└── result.tsv
```

| File               | Contents                                                  |
| ------------------ | --------------------------------------------------------- |
| `command.txt`      | Executed audit command.                                   |
| `metadata.txt`     | Platform, executable, profile, and requested scope.       |
| `version.txt`      | Installed Lynis version-command output.                   |
| `output.log`       | Captured terminal output and errors.                      |
| `lynis.log`        | Detailed native log.                                      |
| `lynis-report.dat` | Native structured audit report.                           |
| `findings.txt`     | Warning and suggestion records extracted from the report. |
| `result.tsv`       | Status, native exit codes, and finding counts.            |

Early failures may not produce all native report files.

Read the findings:

```bash
sudo less /var/log/security-scans/lynis/scan.XXXXXXXX/findings.txt
```

## Exit Codes

| Code | Meaning                                                           |
| ---- | ----------------------------------------------------------------- |
| `0`  | Successful help or dry-run operation.                             |
| `2`  | Native nonzero exit or wrapper/setup/report failure.              |
| `3`  | Native audit returned zero and produced reports; review required. |

Code 3 does not mean malware was found.

The native exit code is retained in `result.tsv`. Profiles can change Lynis's warning-related exit behavior; inspect native nonzero results rather than assuming they always indicate execution failure.

Finding counts are report-record counts, not severity scores.

## Safety and Interpretation

- No automatic remediation or configuration changes are requested.
- Do not apply every hardening suggestion blindly.
- Evaluate findings against the machine's role and operational needs.
- Selected tests and profiles can reduce coverage.
- A completed audit does not prove the system is uncompromised.
- Do not run privileged audits from untrusted software or profiles.
- Use `--help` for all wrapper options.
