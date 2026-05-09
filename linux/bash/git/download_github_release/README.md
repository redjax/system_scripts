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

## Examples

### Install GitTools/GitVersion

[GitVersion releases](https://github.com/GitTools/GitVersion/releases)

> [!NOTE]
> This script tries to download the musl version of GitVersion by default. You must use the `--asset-pattern` flag to tell the script how to download the `gitversion*.tar.gz` archive

```shell
## Linux x86_64
./gh-install.sh --user GitTools --repo GitVersion --asset-pattern 'gitversion-linux-x64-.*\.tar\.gz$'

## Linux x86_64 (musl, Alpine-style libc)
./gh-install.sh --user GitTools --repo GitVersion --asset-pattern 'gitversion-linux-musl-x64-.*\.tar\.gz$'

## Linux aarch64
./gh-install.sh --user GitTools --repo GitVersion --asset-pattern 'gitversion-linux-arm64-.*\.tar\.gz$'

## Linux aarch64 (musl)
./gh-install.sh --user GitTools --repo GitVersion --asset-pattern 'gitversion-linux-musl-arm64-.*\.tar\.gz$'

## macOS x86_64
./gh-install.sh --user GitTools --repo GitVersion --asset-pattern 'gitversion-osx-x64-.*\.tar\.gz$'

## macOS aarch64
./gh-install.sh --user GitTools --repo GitVersion --asset-pattern 'gitversion-osx-arm64-.*\.tar\.gz$'
```

### Install atuinsh/atuin

[Atuin releases](https://github.com/atuinsh/atuin/releases)

> [!NOTE]
> This script tries to download the `atuin-server` bin by default. You must use the `--asset-pattern` flag to tell the script how to download the `atuin*.tar.gz" archive

```shell
## amd64
./gh-install.sh atuinsh/atuin --asset-pattern 'atuin-x86_64-unknown-linux-gnu.tar.gz$'

## amd64 musl
gh-install --user atuinsh --repo atuin --asset-pattern 'atuin-x86_64-unknown-linux-musl\.tar\.gz$'

## aarch64
gh-install --user atuinsh --repo atuin --asset-pattern 'atuin-aarch64-unknown-linux-gnu\.tar\.gz$'

## macOS aarch64
gh-install --user atuinsh --repo atuin --asset-pattern 'atuin-aarch64-apple-darwin\.tar\.gz$'

```

