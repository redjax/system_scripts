# Resticprofile

[`resticprofile`](https://creativeprojects.github.io/resticprofile) is a frontend/wrapper for `restic`. It works off of YAML configurations to abstract the "difficult" parts of `restic`.

## Setup

`resticprofile` can either connect to an existing repository you have (by providing the repository path and password/password file), or initialize a new repository for you. These steps assume you have an existing repository and you want to use `resticprofile` to control your backups.

> [!WARNING]
> Storing your Restic password in a file that the program reads from is bad practice and poor security. You should either set the password as an environment variable (`RESTIC_PASSWORD=...`), or use `restic`'s `--password-cmd` to load it from a vault.
>
> You also should not use your master key for day-to-day operations. Instead, create a new key with `restic -r path/to/repository key add`, which will prompt you for your master password, then a new password. You can use the new password as your 'access key,' and revoke it at any time with the master key (which you should never save to a file, only a password manager or vault).

`resticprofile` needs a YAML file defining your backup(s), which you pass with `-c path/to/profiles.yaml`. You can name the file whatever you want, but by default `resticprofile` will search for a `profiles.yaml` in the current directory and at `~/profiles.yaml`.

## Usage

- Create a [`profiles.yaml` file](#example-profilesyaml) defining your backup profiles
- Create a password for your repository, if you are starting a new one.
  - You can use `resticprofile generate --random-key > password.txt`
- Initialize your repository (if you haven't already) with `resticprofile init`
  - If you set a `schedule` in any of your profiles, you can run `resticprofile schedule` to automatically add your `default` profile's schedule to your platform's task scheduler (`cron` on Linux, `Task Scheduler` on Windows, etc)
- Test your backup configuration by running `resticprofile --dry-run backup`
  - You can test individual backup profiles by passing `--name <profile_name>`
- https://creativeprojects.github.io/resticprofile/configuration/copy/index.html
- Optionally, you can add [command completion](https://creativeprojects.github.io/resticprofile/installation/shell/index.html) to your shell
  - On Linux, you can install them permanently with `resticprofile generate --bash-completion > /etc/bash_completion.d/resticprofile && chmod +x /etc/bash_completion.d/resticprofile`

## Example profiles.yaml

This is the 'bare minimum' required for a `profiles.yaml` file:

```yaml
# yaml-language-server: $schema=https://creativeprojects.github.io/resticprofile/jsonschema/config.json
---
version: "1"

default:
  repository: "/path/to/restic-repo"
  password-file: "/path/to/restic_pw"
  backup:
    source:
      - "/path/to/backup"

```

> [!NOTE]
> The profile below contains many of the possible options you can use in a `profiles.yaml`, but you do not need to declare all/many of these. You can [read more about `resticprofile`'s configuration file here](https://creativeprojects.github.io/resticprofile/configuration/index.html).
>
> Note that you can also [split your configuration into multiple parts using `includes`](https://creativeprojects.github.io/resticprofile/configuration/include/index.html)
>
> Also check the [`resticprofile` configuration reference page](https://creativeprojects.github.io/resticprofile/reference/index.html).

```yaml
# yaml-language-server: $schema=https://creativeprojects.github.io/resticprofile/jsonschema/config.json
---
version: "1"

## Global commands apply to all profiles, unless overridden locally.
global:
  ## The command to run when no operation is passed to a resticprofile command.
  #  There are many options for default-command, like 'snapshots', 'backup', and 'prune'
  default-command: backup
  ## Initialize repository if it doesn't exist
  initialize: false
  ## Set CPU priority. Can affect backup speed, but uses less resources.
  #  https://creativeprojects.github.io/resticprofile/configuration/priority/index.html
  priority: low
  ## Restic won't start unless there are at least n MB free of RAM
  min-memory: 100

## Defaults that profiles can inherit with 'inherit: default'
default:
  ## Path to your restic repository
  repository: "/path/to/restic-repo"
  ## Path to a file containing the path to your restic repository
  # repository-file: "/path/to/restic_repo_file"
  ## Command to run to get password (i.e. read from vault)
  # password-command: ""
  ## Path to a file with your restic repository password
  password-file: "/path/to/restic_pw"

  ## Define backup retention policy
  #  https://creativeprojects.github.io/resticprofile/reference/profile/retention/index.html
  retention:
    ## Run cleanup after backups
    after-backup: true
    ## Keep n most recent backups
    keep-last: 2
    ## Keep n most reecent hourly backups
    keep-hourly: 24
    ## Keep n most recent daily backups
    keep-daily: 7
    ## Keep n most recent weekly backups
    keep-weekly: 4
    ## Skip cleanup if a profile has the 'forever' tag
    keep-tag:
      - forever
    ## Run prune operation on cleanup
    prune: true
    ## Tag can be a boolean or a custom set of tags.
    #  If 'true', copy tag set from backup
    tag:
      - resticprofile

  ## Backup operation defaults
  #  https://creativeprojects.github.io/resticprofile/reference/profile/backup/index.html
  backup:
    ## Disable verbose logging by default
    verbose: false
    ## Exclude other filesystems, don't cross filesystem boundaries & subvolumes
    one-file-system: false
    ## Set number of files that can be read concurrently
    read-concurrency: 2
    ## Skip snapshot creation if identical to parent snapshot
    skip-if-unchanged: true
    ## Path patterns to exclude.
    #  These can also be loaded from a file with exclude-file:
    #  You can use 'iexclude' to ignore cases in path names
    exclude:
      - ".tmp/"
      - ".cache/"
    ## Path(s) to restic exclude pattern files.
    #  You can use 'iexclude' to ignore path casing when searching for file
    exclude-file:
      - "/path/to/resticignore"
    ## On Windows, exclude online-only cloud files like Onedrive "files on demand"
    exclude-cloud-files: false
    ## Set size limit on individual files in the backup repository.
    #  i.e. 50K, 500M, 10G, 1T
    exclude-if-larger-than: ""
    ## Comma-separated list of options for grouping snapshots.
    #  options are 'host', 'paths', 'tags', and can be combined with a comma,
    #  like: 'host,paths'
    group-by: "host,paths"

  ## Checks the repository for errors
  #  https://creativeprojects.github.io/resticprofile/reference/profile/check/index.html
  check:
    ## Run checks on a given schedule.
    #  Can be a string like 'weekly', a comma-separate list of timestamps like 10:00,14:00,
    #  or cron-like syntax like *-*-15 02:45 or Mon..Fri 00:30
    schedule: "weekly"
    ## If repository is remote, you can disable checks when network is offline
    schedule-after-network-online: false
    ## Don't do checks when running on battery
    schedule-ignore-on-battery: false
    ## Ignore when on battery and lower than n%
    schedule-ignore-on-battery-less-than: 20
    ## Read all data blobs
    read-data: true
    ## Use existing cache when 'true', only read uncached data from repository
    with-cache: false

  ## Cache settings
  #  https://creativeprojects.github.io/resticprofile/reference/profile/cache/index.html
  cache:
    ## Enable cache cleanup
    cleanup: false
    ## Set max age in days for cache directories
    max-age: 30
    ## Do not output size of cache directories
    no-size: false

  ## Ignore restic warnings when files cannot be read
  no-error-on-warning: true

## Define backup groups. Run resticprofile with -n <group_name>
#  to run all of the backups in that group
groups:
  basic:
    - home

  full_backup:
    - home

## Example backup /home/username directory
home:
  ## Inherit from the 'default' profile above
  inherit: default

  ## Define backup
  backup:
    ## Override 'verbose: false' from default
    verbose: true
    ## Set backup source(s)/target(s) (the path/paths to back up)
    source:
      - "/home/username"  # on Windows you can use C:\\Users\\username
    ## Path(s) to restic exclude patterns file(s)
    exclude-file:
      - "/path/to/resticignore"
      - "/path/to/restic_home_ignore"
    ## Set tags on the backup
    tags:
      - home
      - userland
    ## Check repository every 1st day of the month at 3:00
    check:
      schedule: "*-*-01 03:00"

## Example backup to Backblaze B2
b2_example:
  inherit: default
  repository: "b2:your-bucket:/restic-backups"
  ## Override default/global password file option
  #  Note: you should really use an env var or password-cmd for this
  password-file: "/path/to/b2_pw"
  backup:
    source:
      - "/some/path/to/backup"
    exclude-file:
      - "/path/to/restic_b2ignore"
  ## It's better to set these in environment variables, or to prefix the command
  #  with vars, i.e. B2_ACCOUNT_ID="..." B2_APPLICATION_KEY="..." resticprofile --name full_backup backup
  env:
    B2_ACCOUNT_ID: "..."
    B2_APPLICATION_KEY: "..."

    ## To load from the environment, use this template syntax
    #  https://creativeprojects.github.io/resticprofile/configuration/templates/index.html
    B2_ACCOUNT_ID: "{{ .Env.MY_CUSTOM_ID }}"
    B2_APPLICATION_KEY: "{{ .Env.MY_CUSTOM_KEY }}"

## Example rclone backup
rclone_backup:
  inherit: default
  repository: "rclone:your-remote:restic-backups"
  backup:
    source:
      - "/home/username"
    tags:
      - rclone
      - home
      - userland
  env:
    ## Set path to rclone.conf file. Looks in ~/.config/rclone/rclone.conf by default
    RCLONE_CONFIG: "{{ .Env.RCLONE_CONFIG | or \"~/.config/rclone/rclone.conf\" }}"

## Example pcloud backup
pcloud-backup:
  inherit: default
  repository: "rclone:pcloud:restic-backups"
  backup:
    source:
      - "/home/username"
    tags:
      - pcloud
      - home
      - userland
  env:
    RCLONE_CONFIG: "{{ .Env.RCLONE_CONFIG | or \"~/.config/rclone/rclone.pcloud.conf\" }}"

## Example SSH/SFTP backup
#  You should configure an entry in ~/.ssh/config and copy your keys in advance
sftp-backup:
  inherit: default
  ## You can parametrize this, i.e.
  #  repository: "sftp:{{ .Env.SFTP_USER }}@{{ .Env.SFTP_HOST }}:{{ .Env.SFTP_PATH }}"
  repository: "sftp:user@host:/path/to/restic-repo"
  backup:
    source:
      - "/home/username"
    tags:
      - sftp
  env:
    ## Optional SSH config file path or overrides.
    #  Using key-based auth may fail if this is not set.
    #  Specific to UNIX-like OSes (Linux, macOS).
    SSH_AUTH_SOCK: "{{ .Env.SSH_AUTH_SOCK }}"

```

## Links

- [Restic Profile home](https://creativeprojects.github.io/resticprofile/index.html)
- [Restic Profile Github](https://github.com/creativeprojects/resticprofile)
- [profiles.yaml examples](https://creativeprojects.github.io/resticprofile/configuration/examples/index.html)
