# Git mirror

Git mirroring clones a branch exactly as it is on the remote. It clones all refs as-is (branches, tags, etc).

The [`local-mirror.sh` script](./local-mirror.sh) creates a mirror of a remote repository on the local filesystem. This can be useful for archiving repositories.

## Parallel Execution

The [`parallel-mirror.sh` script](./parallel-mirror.sh) enables loading repositories from a [`repos.txt` file](./example.repos.txt) and mirroring them concurrently. It uses environment variables or CLI args for remote tokens (for private repos), and the host's SSH config (`~/.ssh/config`) for `git@<remote>:username/repo` patterns.

The text file has 3 "columns", and uses a pipe `|` for the delimiter:

```text
repo-url|local-path|method
```

The 3rd "method" column is really only used for printing the clone/mirror method in the CLI when the application is running. It doesn't matter what you put there, but you have to put *something*. If you don't want to use that column or aren't sure what to put, just use `none`.

For the local path, you should use subdirectories per forge. If you have the same repository name on Github and Gitlab, for instance, the script would have trouble cloning both repositories to the `/path/on/local/git-backups/repo-name`. Instead, you should use `github/` and `gitlab/` subdirectories, i.e. `/path/on/local/git-backups/github/repo-name` and `/path/on/local/git-backups/gitlab/repo-name`.

Usage:

- Run the [`seed-known-hosts.sh`](./seed-known-hosts.sh) script to prepare SSH for remote connections
- Copy `example.repos.txt` to `repos.txt`.
  - Add some URLs.
  - If you are using HTTPS and the repository is private, create a token and set the env var for it, or pass with `--<remote-name>-token`.
  - If you are using SSH, make sure you've configured SSH key auth for the remote.
- Run `./parallel-mirror.sh -f repos.txt --dry-run` to print changes.
- Run `./parallel-mirror.sh -f repos.txt` to mirror repositories.

## Example script

You can use a script to call the `parallel-mirror.sh` script, passing override values & keeping config & repos out of the git path. For example, this script at `~/git_mirrors/run-mirror-script.sh`:

```shell
#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_FILE="/path/to/system_scripts/linux/bash/git/mirror/parallel-mirror.sh"  # set path to the system_scripts repo
ENV_FILE="${DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  . "${ENV_FILE}"
fi

GITHUB_TOKEN="${GIT_GITHUB_TOKEN:-}"
GITLAB_TOKEN="${GIT_GITLAB_TOKEN:-}"
CODEBERG_TOKEN="${GIT_CODEBERG_TOKEN:-}"

REPOS_FILE="${MIRROR_REPOS_FILE:-${DIR}/repos.txt}"
LOGS_DIR="${MIRROR_LOG_DIR:-${DIR}/logs}"
REPOS_DIR="${MIRROR_REPOS_DIR:-${DIR}/repos}"
STATE_DIR="${DIR}/state"

cmd=(/bin/bash "${SCRIPT_FILE}" -f "${REPOS_FILE}" --log-dir "${LOGS_DIR}" --state-dir "${STATE_DIR}" --repos-dir "${REPOS_DIR}")

echo ""
echo "Mirroring git repos"

"${cmd[@]}" 

```

This script looks for a `.env` file in the same path to source values like the github/gitlab/codeberg token, gotify url & token, etc:

```env
export GIT_GITHUB_TOKEN="ghp_XXXXX"
export GIT_GITLAB_TOKEN="glpat-XXXXX"
export GIT_CODEBERG_TOKEN="XXXXXXXXXXXX"

export MIRROR_REPOS_FILE="./repos.txt"
export MIRROR_REPOS_DIR="/path/to/git_mirrors"
export MIRROR_STATE_DIR="./state"
export MIRROR_LOG_DIR="./logs"
export MIRROR_MAX_JOBS=5

export GOTIFY_URL="https://gotify.example.com"
export GOTIFY_TOKEN=""

```

This can be scheduled with cron:

```shell
## Git mirror
0 */6 * * * cd /path/to/git_mirrors && { /bin/bash -x ./run-mirror-script.sh >> logs/cron-job.log 2>&1; }
```

If you use a notification service like Gotify, you can also create a script to send a notification on failure:

```shell
#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >&/dev/null; then
  echo "[ERROR] curl is not installed" >&2
  exit 1
fi

GOTIFY_URL=""
GOTIFY_TOKEN=""

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${DIR}/.env"

. "${ENV_FILE}"

URL="${GOTIFY_URL:-}/message"
TOKEN="${GOTIFY_TOKEN:-}"

if [[ -z "${URL}" ]]; then
  echo "[ERROR] Gotify URL is not set" >&2
  exit 1
fi

if [[ -z "${TOKEN}" ]]; then
  echo "[ERROR] Gotify token is not set" >&2
  exit 1
fi

# echo "[DEBUG] URL: ${URL}"
# echo "[DEBUG] TOKEN: ${TOKEN}"

curl "${URL}?token=${TOKEN}" -F "title=Git Mirror Failed" -F "message=Scheduled git mirror job on ${HOSTNAME} failed" -F "priority=3"

```

And update the cron job:

```shell
0 */6 * * * cd /path/to/git_mirrors && { /bin/bash -x ./run-mirror-script.sh >> logs/cron-job.log 2>&1 || /bin/bash ./send-failure-notification.sh; }
```

