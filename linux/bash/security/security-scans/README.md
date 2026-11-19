# Security Scan Orchestrator

`run-scans.sh` runs selected scanner adapters, or all supported adapters, and collects their results in one batch report.

Scanners:

- ClamAV
- rkhunter
- chkrootkit
- Lynis
- Maldet
- Trivy

> [!NOTE]
> Install and configure each scanner separately before using the orchestrator. It does not install tools, explicitly invoke signature-update scripts, accept baselines, or remediate findings. Trivy may download or refresh its databases as part of a scan.

## Quick Start

List platform support and adapter availability:

```bash
./run-scans.sh --list
```

Preview all commands:

```bash
./run-scans.sh \
  --all \
  --target "$HOME/projects" \
  --sudo \
  --dry-run
```

Run all supported scanners:

```bash
./run-scans.sh \
  --all \
  --target "$HOME/projects" \
  --sudo \
  --verbose
```

> [!NOTE]
> Run as your normal user with `--sudo` so user-specific paths are resolved before adapter commands are elevated.
>
> `--all` defaults Trivy to filesystem mode against the supplied targets. It does not automatically scan the host root or discover container images.

## Select Scanners

Run host checks only:

```bash
./run-scans.sh \
  --scanners rkhunter,chkrootkit,lynis \
  --sudo
```

Run file scanners against multiple targets:

```bash
./run-scans.sh \
  --scanners clamav,maldet \
  --target /var/www \
  --target /srv \
  --sudo
```

Host scanners run once. ClamAV, Maldet, and Trivy filesystem/rootfs modes run separately for each target. Trivy image mode runs separately for each image.

`--all` selects adapters supported by this suite on the current platform. Missing selected adapter scripts or native tools are errors, not silent skips.

## Trivy Modes

Trivy reports security findings such as known vulnerabilities. These are classified separately from ClamAV/Maldet malware hits.

### Application Filesystem

Scan an application directory and supported dependency metadata:

```bash
./run-scans.sh \
  --scanners trivy \
  --trivy-mode filesystem \
  --target /srv/my-app \
  --trivy-severity HIGH,CRITICAL \
  --verbose
```

Filesystem mode is the default. Trivy filesystem/rootfs targets must be directories.

### Linux Host / Root Filesystem

Run a host-focused scan with an explicit timeout and exclusions:

```bash
./run-scans.sh \
  --scanners trivy \
  --trivy-mode rootfs \
  --target / \
  --trivy-timeout 30m \
  --trivy-skip-dir /proc \
  --trivy-skip-dir /sys \
  --trivy-skip-dir /dev \
  --trivy-skip-dir /run \
  --trivy-skip-dir /var/lib/docker \
  --trivy-skip-dir /var/lib/containerd \
  --sudo \
  --verbose
```

This adapter enables rootfs mode only on Linux, and the orchestrator requires root or `--sudo` for that mode.

Excluding container storage also excludes its application data and volumes. Scan important application directories and container images separately.

Do not use `--all --target /` merely to request a Trivy host scan: it also sends `/` to ClamAV and Maldet.

### Container Images

```bash
./run-scans.sh \
  --scanners trivy \
  --trivy-mode image \
  --image example/app:tag \
  --image example/worker:tag \
  --verbose
```

Image mode requires at least one `--image` and does not consume `--target`.

When combined with ClamAV or Maldet, targets apply to those scanners and image references apply to Trivy:

```bash
./run-scans.sh \
  --scanners clamav,maldet,trivy \
  --target /var/www \
  --trivy-mode image \
  --image example/app:tag \
  --sudo
```

> [!IMPORTANT]
> `--sudo` elevates every adapter, including Trivy image scans. This can change the registry credentials, runtime access, and cache used by Trivy.
> Omit it for image-only scans when elevation is unnecessary.

### Trivy Policy

Vulnerability scanning is enabled by default. Additional scanners are opt-in:

```bash
./run-scans.sh \
  --scanners trivy \
  --target /srv/my-app \
  --trivy-scanners vuln,secret,misconfig \
  --trivy-severity HIGH,CRITICAL \
  --verbose
```

All severities are included by default, and unfixed vulnerabilities are not hidden unless `--trivy-ignore-unfixed` is supplied.

Filtering changes what can produce a finding result.

## Common Options

| Option             | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| `--all`            | Select all platform-supported adapters.              |
| `--scanners LIST`  | Select comma-separated scanner names.                |
| `--tools LIST`     | Alias for `--scanners`.                              |
| `--target PATH`    | Repeatable filesystem target.                        |
| `--sudo`           | Elevate all adapter commands when not already root.  |
| `--verbose`        | Stream adapter output while saving it.               |
| `--dry-run`        | Print commands without executing or writing reports. |
| `--output-dir DIR` | Set the batch-report parent directory.               |

### Scanner-Specific Options

| Option                       | Purpose                                          |
| ---------------------------- | ------------------------------------------------ |
| `--clamav-database DIR`      | Select the ClamAV signature directory.           |
| `--clamav-exclude-dir REGEX` | Repeatable ClamAV directory exclusion.           |
| `--maldet-engine NAME`       | `native` or `clamav`; default: `native`.         |
| `--lynis-bin FILE`           | Explicit Lynis executable, useful with Homebrew. |
| `--lynis-profile FILE`       | Alternate Lynis profile.                         |

### Trivy Options

| Option                     | Purpose                                                    |
| -------------------------- | ---------------------------------------------------------- |
| `--trivy-mode MODE`        | `filesystem`, `rootfs`, or `image`; default: `filesystem`. |
| `--image REF`              | Repeatable image reference for image mode.                 |
| `--trivy-scanners LIST`    | `vuln`, `secret`, `misconfig`; default: `vuln`.            |
| `--trivy-severity LIST`    | Default: `UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL`.               |
| `--trivy-timeout DURATION` | Positive `s`, `m`, or `h` duration; default: `15m`.        |
| `--trivy-ignore-unfixed`   | Filter vulnerabilities without a known fix.                |
| `--trivy-ignorefile FILE`  | Explicit ignore file.                                      |
| `--trivy-config FILE`      | Explicit main configuration.                               |
| `--trivy-skip-dir PATH`    | Repeatable directory/pattern exclusion.                    |
| `--trivy-cache-dir DIR`    | Explicit database/cache directory.                         |
| `--trivy-bin FILE`         | Explicit Trivy executable.                                 |

Use `./run-scans.sh --help` for the complete interface.

## ClamAV Database

The default is the invoking user's cache database:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db
```

When launching the entire orchestrator through `sudo`, provide the database explicitly if ClamAV is selected:

```bash
sudo ./run-scans.sh \
  --all \
  --target /var/www \
  --clamav-database /home/jack/.cache/security-scans/clamav/db \
  --output-dir /var/log/security-scans/batches
```

Replace the example database path with your configured location.

## Reports

Reports default to a unique directory beneath:

```text
./security-scan-reports/
```

Each batch contains:

- `metadata.txt`: platform, selected scanners, and Trivy settings.
- `summary.tsv`: per-job status and adapter exit codes.
- `job-*/command.txt`: executed adapter command.
- `job-*/output.log`: captured adapter output.
- `job-*/status.txt`: adapter and output-writer exit codes.
- `job-*/reports/`: adapter-specific reports, when generated.

Maldet also retains native session reports in its own installation.

Trivy saves JSON and readable table reports beneath its job's report directory when scanning and conversion succeed.

Scans run sequentially and continue after individual findings or failures. Avoid placing reports inside scan targets.

Reports may contain sensitive paths, configuration details, and secret findings. Protect them accordingly.

### Result Statuses

| Status              | Meaning                                            |
| ------------------- | -------------------------------------------------- |
| `completed`         | Adapter returned its supported success status.     |
| `malware-hits`      | ClamAV or Maldet reported hits.                    |
| `security-findings` | Trivy reported findings under the selected policy. |
| `review-required`   | Adapter output requires review.                    |
| `error`             | Adapter failed or returned an unexpected status.   |
| `report-error`      | Writing the orchestration output failed.           |

Summary counts represent jobs, not individual vulnerabilities, files, or
warnings.

## Exit Codes

| Code | Meaning                                                 |
| ---- | ------------------------------------------------------- |
| `0`  | All adapters returned their supported success status.   |
| `1`  | At least one malware-hit or Trivy security-finding job. |
| `2`  | At least one adapter, setup, or report-writing failure. |
| `3`  | At least one adapter requires review.                   |

Precedence: error → findings → review required → success.

The summary retains every job's result regardless of the final exit code.
Chkrootkit and Lynis normally request review even after successful execution.

## Troubleshooting Trivy Timeouts

If Trivy reports `context deadline exceeded`:

- Increase `--trivy-timeout`.
- Review whether the target includes container storage, snapshots, caches,
  or large development environments.
- Exclude paths that are outside the intended scope.
- Scan excluded application data or images separately when needed.

The timeout must be forwarded through both layers:

```text
run-scans.sh --trivy-timeout 30m
 -> trivy/scan.sh --timeout 30m
 -> trivy ... --timeout 30m
```

An errored or timed-out scan is incomplete. Do not interpret a missing or
partial report as no findings.

## Limitations

- rkhunter, chkrootkit, and Lynis inspect the running host.
- Targets apply to ClamAV, Maldet, and Trivy filesystem/rootfs modes.
- Trivy image mode uses explicit image references; images are not discovered.
- Scanner limits, exclusions, profiles, and ignore settings still apply.
- Dry-run prints the orchestration plan; it does not validate native scanners.
- Findings require investigation; no automatic remediation occurs.
- A completed batch does not prove the machine is uncompromised.
