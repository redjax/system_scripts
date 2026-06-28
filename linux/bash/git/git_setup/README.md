# Git Setup

Configure git on fresh setup. Set `author.name` and `author.email`, add aliases, set default behavior etc.

Run the [`init-git-setup.sh` script](./init-git-setup.sh) with `-h` to see usage.

Run the [`default-git-setup.sh`](./default-git-setup.sh) for a guided/default setup.

## Download & run

Option 1: Download the script, run in second step

```shell
curl -fsSL https://raw.githubusercontent.com/redjax/system_scripts/refs/heads/main/linux/bash/git/git_setup/init-git-setup.sh -o init-git-setup.sh
chmod +x init-git-setup.sh
./init-git-setup.sh -h
```

Option 2: cURL the script & pass args with `bash -s -- [args]`. To see all options, run with `-- -h`:

```shell
curl -fsSL https://raw.githubusercontent.com/redjax/system_scripts/refs/heads/main/linux/bash/git/git_setup/init-git-setup.sh | bash -s -- -h
```

My default setup is:

```shell
curl -fsSL https://raw.githubusercontent.com/redjax/system_scripts/refs/heads/main/linux/bash/git/git_setup/init-git-setup.sh \
| bash -s -- -u "Your Username" -e "your@email.com" -b "main" -p -f -a -r -E "${EDITOR:-nvim}"
```
