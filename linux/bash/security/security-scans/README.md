# Security Scan Orchestrator

`run-scans.sh` runs selected scanner adapters—or all supported adapters—and collects their results in one batch report.

Scanners:

- ClamAV
- rkhunter
- chkrootkit
- Lynis
- Maldet

> [!NOTE]
> Install and configure each scanner separately before using the orchestrator. It does not install tools, update signatures, accept baselines, or remediate
findings.

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

Host scanners run once. ClamAV and Maldet run separately for each target.

`--all` selects adapters supported by this suite on the current platform. Missing selected adapter scripts or native tools are errors, not silent skips.

## Common Options

| Option                       | Purpose                                              |
| ---------------------------- | ---------------------------------------------------- |
| `--all`                      | Select all platform-supported adapters.              |
| `--scanners LIST`            | Select comma-separated scanner names.                |
| `--target PATH`              | File-scan target; repeatable.                        |
| `--sudo`                     | Elevate adapter commands when needed.                |
| `--verbose`                  | Stream adapter output while saving it.               |
| `--dry-run`                  | Print commands without executing or writing reports. |
| `--output-dir DIR`           | Set the batch-report parent directory.               |
| `--clamav-database DIR`      | Select the ClamAV signature directory.               |
| `--clamav-exclude-dir REGEX` | Add a ClamAV directory exclusion; repeatable.        |
| `--maldet-engine NAME`       | Select `native` or `clamav`; default: `native`.      |
| `--lynis-bin FILE`           | Specify the Lynis executable, useful with Homebrew.  |
| `--lynis-profile FILE`       | Select an alternate Lynis profile.                   |

Use `./run-scans.sh --help` for the complete interface.

## ClamAV Database

The default is the invoking user's cache database:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/security-scans/clamav/db
```

When launching the entire orchestrator through `sudo`, provide the database explicitly:

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

- `metadata.txt`: platform and selected scanners.
- `summary.tsv`: per-job status and adapter exit codes.
- `job-*/output.log`: captured adapter output.
- `job-*/reports/`: adapter-specific reports, when generated.

Maldet also retains native session reports in its own installation. Scans run sequentially and continue after individual findings or failures. Avoid placing reports inside scan targets.

## Exit Codes

| Code | Meaning                                                 |
| ---- | ------------------------------------------------------- |
| `0`  | All adapters returned their supported success status.   |
| `1`  | At least one file scanner reported malware hits.        |
| `2`  | At least one adapter, setup, or report-writing failure. |
| `3`  | At least one adapter requires review.                   |

Precedence: error → malware hits → review required → success.

The summary retains every job's result regardless of the final exit code. Chkrootkit and Lynis normally request review even after successful execution.

## Limitations

- Targets apply only to ClamAV and Maldet; other adapters inspect the host.
- Scanner limits, exclusions, profiles, and ignore settings still apply.
- Dry-run prints the orchestration plan; it does not validate native scanners.
- Findings require investigation; no automatic remediation occurs.
- A completed batch does not prove the machine is uncompromised.
