# Git Rewrite History

Ever accidentally committed code from the wrong git user/email? Rewrite history!

## Manual Process

Install the `git-filter-repo` Python package with `pip install git-filter-repo`
- Clone the repository in a new directory using the `--bare` flag, i.e.:
	- `git clone --bare git@github.com:user/repo.git`
- Run a command like the following, replacing the `Old Name`, `old.email@example.com`, `New Name`, and `new.email@example.com` with your old/new author:

```shell
git filter-branch --env-filter '
if [ "$GIT_COMMITTER_NAME" = "Old Name" ] && [ "$GIT_COMMITTER_EMAIL" = "old.email@example.com" ]; then
    GIT_COMMITTER_NAME="New Name"
    GIT_COMMITTER_EMAIL="new.email@example.com"
    GIT_AUTHOR_NAME="New Name"
    GIT_AUTHOR_EMAIL="new.email@example.com"
fi
' --tag-name-filter cat -- --branches --tags

```

- Clean refs & ensure proper pruning

```shell
git reflog expire --expire=now --all
git gc --prune=now

```

- Force push changes

```shell
git push --force --all
git push --force --tags

```

- Clone the repository again (do a fresh clone in a new path on your local machine, if you already cloned the repository before)
- Check for any hints of the old name:
	- `git log --author="Old Name"`

## Script

Use the [`rewrite-commit-history.sh` script](./rewrite-commit-history.sh) to provide the source username/email, the remote repo URL, and let Bash handle the rest.
