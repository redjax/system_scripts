# Git mirror

Git mirroring clones a branch exactly as it is on the remote. It clones all refs as-is (branches, tags, etc).

The [`local-mirror.sh` script](./local-mirror.sh) creates a mirror of a remote repository on the local filesystem. This can be useful for archiving repositories.

## Parallel Execution

The [`parallel-mirror.sh` script](./parallel-mirror.sh) enables loading repositories from a [`repos.txt` file](./example.repos.txt) and mirroring them concurrently. It uses environment variables or CLI args for remote tokens (for private repos), and the host's SSH config (`~/.ssh/config`) for `git@<remote>:username/repo` patterns.

Usage:

- Run the [`seed-known-hosts.sh`](./seed-known-hosts.sh) script to prepare SSH for remote connections
- Copy `example.repos.txt` to `repos.txt`.
  - Add some URLs.
  - If you are using HTTPS and the repository is private, create a token and set the env var for it, or pass with `--<remote-name>-token`.
  - If you are using SSH, make sure you've configured SSH key auth for the remote.
- Run `./parallel-mirror.sh -f repos.txt --dry-run` to print changes.
- Run `./parallel-mirror.sh -f repos.txt` to mirror repositories.
