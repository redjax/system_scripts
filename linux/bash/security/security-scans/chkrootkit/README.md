# chkrootkit Scripts

Install chkrootkit and run rootkit-oriented host checks. This adapter currently only supports Linux.

## Files

| Script       | Purpose                                               |
| ------------ | ----------------------------------------------------- |
| `install.sh` | Install chkrootkit from enabled package repositories. |
| `scan.sh`    | Run checks and save per-run reports.                  |
| `lib.sh`     | Shared helper functions.                              |

There is no baseline or separate signature-update script in this adapter. Update the installed tool through its package manager.

## Installation

```bash
./install.sh --dry-run
./install.sh
```

Package-manager paths include APT, DNF, YUM, Zypper, Pacman, and APK. Package availability varies by release and enabled repositories. The installer does not enable repositories or build AUR/source packages.

## Scanning

Preview:

```bash
./scan.sh --dry-run
```

Run and display output:

```bash
sudo ./scan.sh --verbose
```

Without `--verbose`, full output is still saved to the report.

List supported tests:

```bash
./scan.sh --list-tests
```

Run selected tests:

```bash
sudo ./scan.sh \
  --test sshd \
  --test login \
  --verbose
```

Selected tests reduce coverage. Make supported tests skip NFS-mounted directories:

```bash
sudo ./scan.sh --skip-nfs --verbose
```

## Alternate Root

```bash
sudo ./scan.sh --root /mnt/inspection --verbose
```

This changes the filesystem root used by applicable checks. Do not assume every runtime/process check becomes an offline filesystem check.

## Trusted Commands

Supply trusted external command directories when available:

```bash
sudo ./scan.sh \
  --trusted-path /media/trusted/bin:/media/trusted/sbin \
  --verbose
```

The wrapper verifies directory existence, not the trustworthiness of their contents.

## Package Helper Layouts

Some package layouts require running from a directory containing chkrootkit's helper programs.

Use the directory appropriate to the installed package:

```bash
sudo ./scan.sh --work-dir /path/to/package/helpers --verbose
```

Do not assume a scan was complete if the report says helper programs were missing or tests could not run.

## Reports

Default parent directory:

```text
/var/log/security-scans/chkrootkit/
```

Each run creates:

```text
scan.XXXXXXXX/
├── command.txt
├── metadata.txt
├── version.txt
├── output.log
└── result.tsv
```

Override the parent directory with `--output-dir`.

## Exit Codes

| Code | Meaning                                                      |
| ---- | ------------------------------------------------------------ |
| `0`  | Successful dry-run or test-list operation.                   |
| `2`  | Native nonzero exit or wrapper/setup/report-writing failure. |
| `3`  | Native scan returned zero; report requires review.           |

Code 3 does not mean malware was found. The adapter does not classify native text output as confirmed infection. Native exit codes are retained in `result.tsv`.

## Safety

- No automatic deletion, remediation, or allowlisting.
- Findings require investigation.
- Missing helpers and skipped checks affect coverage.
- A successful invocation does not prove the host is uncompromised.
- The suite lock coordinates these wrappers, not unrelated scheduled jobs.
- Use `--help` for the complete interface.
