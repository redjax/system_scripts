# Download Github Release

Generic script to download releases from Github repositories.

Fetches the latest release via the Github REST API. Detects OS/CPU to pick a matching asset, where possible. Downloads to `/tmp`, extracts archives, and installs binaries to target directory.

Run with `--dry-run` to show what would happen without making any changes.

## Requirements

- `curl`
- `jq`
- `find`
- `tar`
- `unzip`

## Usage

Basic usage:

```shell
./gh-install .sh owner/repo
```

You can also pass the user and repo manually:

```shell
./gh-install.sh --user owner --repo repositoryName
```

Add a `--dry-run` to show actions without executing them:

```shell
./gh-install.sh --dry-run owner/repo
```

Pass a custom install directory:

```shell
./gh-install.sh --install-dir "$HOME/.local/bin" owner/repo
```

Give script a custom pattern to match non-standard release file names:

```shell
./gh-install.sh owner/repo --asset-pattern 'filename-.*-x86_64-unknown-linux-gnu.tar.gz'
```

