# Restic <!-- omit in toc -->

[Restic](https://restic.net) is a flexible & fast backup tool. It works with a repository system, storing differential snapshots of paths you add to the repository each time you run the backup command.

Restic is [scriptable](https://restic.readthedocs.io/en/latest/075_scripting.html), too, making it great for scheduled backups.

## Table of Contents <!-- omit in toc -->

- [Setup](#setup)
- [Links](#links)

## Setup

- Install Restic ([docs](https://restic.readthedocs.io/en/latest/020_installation.html))
  - You can use the [`install_restic.sh`](./install_restic.sh) script to install on Linux and Mac.
  - Use `scoop install restic` on Windows.
- (Optional) Create a directory to store restic data in, i.e. `mkdir -p ~/.restic`
  - Create a file `repo_path`, and set the path where you want to store the backup repository (i.e. `/opt/restic-repo`)
  - If you want to read your backup password from a file (note: this is not very secure, but ok for home backups if you don't have sensitive data in the backup. Generally advisable to use a password vault, i.e. [Bitwarden](https://www.google.com/bitwarden)), create a directory `~/.restic/passwords`.
    - Don't store your master password in a file here! Instead, create a second password, your "user access password," and paste it in a file like `user_access`.
  - If you want to use `--exclude-file` (to read gitignore-like exclusion patterns from a file), you can create a `excludes/` directory in your `~/.restic` directory
- Initialize a backup repository with `restic init --repository-file ~/.restic/repo_path`
  - This will prompt you to set a master password. Make it strong, and store it in a vault somewhere.
  - It is not advisable to store this password in a file on your machine; you can [create repository 'keys'](https://restic.readthedocs.io/en/latest/070_encryption.html#manage-repository-keys), which are basically just other passwords you can use and revoke for the repository.
- After initializing a repository, create a 'user access' key by running `restic --repository-file ~/.restic/repo_path key add`
    - This will prompt you for your master password, then for a secondary password you can use to open the repository.
    - At any time you can revoke this key/password by running `restic --repository-file ~/.restic/repo_path key <keyId>`
      - You can get the `keyId` by running `restic --repository-file ~/.restic/repo_path key list`

> [!TIP]
> If you don't want to have to type `--repository-file ~/.restic/repo_path` every time, you can set an environment variable `RESTIC_REPOSITORY_FILE="~/.restic/repo_path"`.
>
> You can do the same thing for your user access password by setting `RESTIC_PASSWORD_FILE="~/.restic/passwords/user_access`
>
> Now, you can just run your `restic` commands directly, i.e. `restic_snapshots`.

## Links

- [Restic home](https://restic.net)
- [Restic docs](https://restic.readthedocs.io)
  - [Restic installation docs](https://restic.readthedocs.io/en/latest/020_installation.html)
  - [Restic CLI reference](https://restic.readthedocs.io/en/latest/manual_rest.html)
  - [Prepare new Restic repository](https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html)
  - [Backing up](https://restic.readthedocs.io/en/latest/040_backup.html)
  - [Restoring from backup](https://restic.readthedocs.io/en/latest/050_restore.html)
    - [Restore from snapshot](https://restic.readthedocs.io/en/latest/050_restore.html#restoring-from-a-snapshot)
    - [Restore to mount point](https://restic.readthedocs.io/en/latest/050_restore.html#restore-using-mount)
    - [Print files to stdout](https://restic.readthedocs.io/en/latest/050_restore.html#printing-files-to-stdout)
  - [Scripting restic](https://restic.readthedocs.io/en/latest/075_scripting.html)
- [Restic Github](https://github.com/restic/restic)
