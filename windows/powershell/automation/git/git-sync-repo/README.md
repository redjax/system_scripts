# Git mirror synch script

*NOTE: I have broken this script out into [its own repository](https://github.com:redjax/git-sync-repos). The files in this path may not be the most recent version of the script. I will try to update this script if I make changes in the git-sync-repos script.*

Mirror git repositories from one remote to another (i.e. a Github repository to Codeberg).

## Setup

Before running this script, make sure your repositories are public, or that you've added a public SSH key to both the source and target repository. Instructions for adding your SSH key [to Github](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account), [to Codeberg](https://docs.codeberg.org/security/ssh-key/), and [to Gitlab](https://docs.gitlab.com/ee/user/ssh.html).

- Copy [`mirrors.example`](./mirrors.example) to `mirrors` (this file should not have a file extension).
  - Edit `mirrors`, deleting the examples and adding your own mirror pairs.
- Run the [`git_mirror_sync.ps1`](./git_mirror_sync.ps1) script.
  - The script will read the `mirrors` file, create a `./repositories/` path, and clone each repository source, then mirror to the target.
