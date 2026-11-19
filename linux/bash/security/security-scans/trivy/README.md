# Trivy Scripts

Install Trivy and scan Linux root filesystems, application directories,
or container images.

Trivy findings identify vulnerabilities, secrets, or misconfigurations.
They do not establish that malware is installed or that exploitation occurred.

## Installation

```bash
./install.sh --dry-run
./install.sh
```

The installer downloads a pinned official release, verifies its published
SHA-256 checksum, and installs the binary to `/usr/local/bin`.

Requirements: curl, tar, and sha256sum or shasum.

Supported binary targets: Linux/macOS on x86-64 or ARM64.

Install or replace a specific release:

```bash
./install.sh --version 0.76.1 --force
```

Install under your home directory:

```bash
./install.sh --install-dir "$HOME/.local/bin"
```

Published checksums detect corruption but are not independent authentication
of the upstream release.

## Scan Modes

### Application directory

```bash
./scan.sh \
  --mode filesystem \
  --target /srv/my-app \
  --verbose
```

### Linux host/root filesystem

```bash
sudo ./scan.sh \
  --mode rootfs \
  --target / \
  --verbose
```

This adapter enables rootfs mode only on Linux.

### Container image

```bash
./scan.sh \
  --mode image \
  --image example/app:tag \
  --verbose
```

Image access can require registry credentials or container-runtime access.
Use an image digest when you need an immutable target.

## Scan Policy

Vulnerability scanning is the default. All severities are included, and
unfixed vulnerabilities are not hidden by default.

Enable additional scanners explicitly:

```bash
./scan.sh \
  --mode filesystem \
  --target /srv/my-app \
  --scanners vuln,secret,misconfig \
  --verbose
```

Limit severity and hide vulnerabilities without a known fix:

```bash
./scan.sh \
  --mode filesystem \
  --target /srv/my-app \
  --severity HIGH,CRITICAL \
  --ignore-unfixed
```

A zero result means no findings under the selected policy, not no possible
security issues.

Additional options:

- `--config FILE`: explicit main Trivy configuration.
- `--ignorefile FILE`: explicit ignore file.
- `--skip-dir PATH`: repeatable directory/pattern exclusions.
- `--cache-dir DIR`: database/cache location.
- `--trivy-bin FILE`: explicit executable path.
- `--output-dir DIR`: report parent directory.
- `--dry-run`: show the command without running it.

The wrapper supplies an empty main configuration and empty ignore file
unless you explicitly select them. Native environment variables and other
scanner-specific configuration can still affect behavior.

Trivy downloads or refreshes its vulnerability databases as required.
There is no separate update script in this adapter.

## Reports

Default parent directory: `./trivy-reports/`

Each run creates:

```text
scan.XXXXXXXX/
├── command.txt
├── metadata.txt
├── version.txt
├── output.log
├── report.json
├── report.txt
├── convert.log
└── result.tsv
```

JSON is the primary scan report. The table is converted from that JSON
without running another vulnerability scan.

Early errors may prevent report generation.

Reports can contain sensitive paths and secret findings. Protect them.

## Exit Codes

| Code | Meaning                                               |
| ---- | ----------------------------------------------------- |
| `0`  | No findings under the selected scan policy.           |
| `1`  | Selected findings detected.                           |
| `2`  | Execution, dependency, conversion, or report failure. |

The native finding exit code is 10; the wrapper normalizes it to 1.
Native status is preserved in result.tsv.

## Limitations

- Coverage depends on mode, supported package ecosystems, and available metadata.
- Host scans do not replace explicit container-image scans.
- Filtering and exclusions reduce reported coverage.
- No automatic remediation is performed.
- Use `--help` for the complete interface.
