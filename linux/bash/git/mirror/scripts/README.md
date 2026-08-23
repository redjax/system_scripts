# Simple Mirror Scripts

Lightweight, one-off Git mirroring wrappers.

## Scripts

- `mirror-local.sh`
  - Create or update a local bare mirror from a source repository.
- `mirror-local-to-remote.sh`
  - Create/update a local bare mirror, then push that mirror to a destination remote.
- `mirror-remote-to-remote.sh`
  - Mirror a source repository directly to a destination remote using a temporary local mirror.

## Usage

```bash
## Source to local bare mirror
./mirror-local.sh <source-url> [--local-root <dir>]

## Source to local bare mirror, then to destination remote
./mirror-local-to-remote.sh <source-url> <destination-url> [--local-root <dir>]

## Source to destination remote (temporary local mirror)
./mirror-remote-to-remote.sh <source-url> <destination-url>
```

## Examples

```bash
./mirror-local.sh git@github.com:my-org/service-a.git

./mirror-local-to-remote.sh \
  git@github.com:my-org/service-a.git \
  git@gitlab.com:my-org/service-a.git

./mirror-remote-to-remote.sh \
  git@github.com:my-org/service-a.git \
  git@codeberg.org:my-org/service-a.git
```
