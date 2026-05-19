# git-mirror

Bash scripts to automate creating Git mirrors. Can create local mirror archives, or handle replication between remotes. Uses Git URLs, so the scripts should work with any compliant forge (Github, Gitlab, Codeberg, Azure DevOps, etc).

There are 2 main entrypoint scripts:

- `mirror-git-repo` for mirroring a single repository
- `mirror-multi` for batch runs with parallel jobs, retries, and logs

## Requirements

- bash
- git
- flock (`util-linux`)
- yq (YAML jobs only)

To install/verify required tools (especially the correct Mike Farah `yq`), run:

```bash
./install-requirements.sh
```

Optional:

```bash
./install-requirements.sh --force
./install-requirements.sh --version v4.44.3
INSTALL_DIR="$HOME/.local/bin" ./install-requirements.sh
```

## Usage

General usage:

```bash
./mirror-git-repo <mirror|sync|replicate> <source-url> [options]
```

Run either script with `--help` to see help/usage menu.

### Examples

- local bare mirror under ./repos
  
  ```bash
  ./mirror-git-repo mirror git@github.com:org/repo.git
  ```

- local mirror + push to destination remote

  ```shell
  ./mirror-git-repo sync git@github.com:org/repo.git \
    --dest gitlab=git@gitlab.com:org/repo.git
  ```

- run a batch from `jobs.yml`

  ```shell
  ./mirror-multi --jobs-yaml jobs.yml --parallel 8 --retries 2
  ```

#### Auth examples

```bash
# SSH agent / default SSH setup
./mirror-git-repo mirror git@github.com:org/private-repo.git

# explicit private key file
./mirror-git-repo mirror git@github.com:org/private-repo.git \
  --ssh-key-file /run/secrets/id_ed25519

# HTTPS token from env var
export GIT_TOKEN=your_token_here
./mirror-git-repo mirror https://github.com/org/private-repo.git \
  --https-token-env GIT_TOKEN
```

You can set defaults as environment variables, too:

```bash
export MIRROR_LOCAL_ROOT=./repos
export AUTH_MODE=ssh
```

## Mirror vs sync vs replicate

- mirror: keep local bare mirror only

  ```shell
  ./mirror-git-repo mirror git@github.com:org/repo.git
  ```

- sync: keep local mirror and push to one or more remotes

  ```shell
  ./mirror-git-repo sync git@github.com:org/repo.git \
    --dest gitlab=git@gitlab.com:org/repo.git \
    --dest codeberg=git@codeberg.org:org/repo.git
  ```

- replicate: source -> destination directly (temporary local clone)

  ```shell
  ./mirror-git-repo replicate git@github.com:org/repo.git \
  git@gitlab.com:org/repo.git
  ```

## mirror-multi

`mirror-multi` reads jobs and calls `mirror-git-repo` for each one.

```bash
./mirror-multi [options]
```

Most-used flags:

```text
--jobs-file <path>      text jobs, one line per job
--jobs-yaml <path>      YAML jobs
--parallel <n>          default: 4
--retries <n>           default: 1
--retry-delay <secs>    default: 2
--resume                skip already-successful jobs
--fail-on-error         return non-zero if any job failed
--clean                 wipe old run/job/status files before run
--dry-run               forwarded to mirror-git-repo
--debug                 forwarded to mirror-git-repo
--verbose               forwarded to mirror-git-repo
```

## Jobs

The `mirror-multi` script can accept a "jobs file" in YAML format, where you can define the cloning operations.

```yaml
jobs:
  - src: git@github.com:username/repo
    dest:
      - local

  - src: git@github.com:my-org/service-a
    dest:
      - local
      - git@gitlab.com:my-org/service-a

  - src: https://github.com/my-org/public-repo
    dest:
      - local
```

```bash
./mirror-multi --jobs-yaml jobs.yml --parallel 8 --retries 2
```

