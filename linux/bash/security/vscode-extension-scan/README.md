# VS Code Extension Scan

Scan your VS Code extensions with [`vsix-scan`](https://github.com/PabloDomi/vsix-scan).

## Setup

- Build the container with [`./scripts/build-container.sh`](./scripts/build-container.sh)

## Usage

- Export your list of extensions with [`./scripts/export-extensions.sh`](./scripts/export-extensions.sh)
- Run the scanner with [`./scripts/scan-extensions.sh`](./scripts/scan-extensions.sh)

The scanner creates a cache in the output directory. The first scan takes a while, but subsequent scans will use the cache and finish quicker.
