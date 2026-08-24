# Git Credential Manager

Installs [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) on a Linux machine.

## Usage

### Azure DevOps

Clone repositories using the HTTPS URL, i.e.: `git clone https://dev.azure.com/companyName/projectName/_git/repo-name`.

#### Option 1: GCM-managed authentication (recommended)

> [!NOTE]
> This setup requires `gpg` and `pass`. Install with:
>
> - Debian-family:
> 
>   ```shell
>   sudo apt update -y && sudo apt install -y gnupg pass pinentry-curses
>   ```
>
> - RedHat-family (RHEL, Fedora, Alma, etc):
>
>   ```shell
>   sudo dnf install -y gnupg2 pass pinentry-curses
>   ```

With this approach, the PAT is not stored in your shell profile or an environment variable. GCM stores the credential using a supported credential store.

For a headless Linux machine, i.e. in WSL, GCM can use GPG/pass for persistent encrypted credential storage.

If you are using a headless environment, configure GPG to use the terminal-based `pinentry` program:

```shell
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg
```

Create or update `~/.gnupg/gpg-agent.conf`:

```shell
echo "pinentry-program $(command -v pinentry-curses)" >> ~/.gnupg/gpg-agent.conf
```

Restart the GPG agent:

```shell
gpgconf --kill gpg-agent
```

Configure `GPG_TTY` so GPG knows which terminal to use for PIN entry:

```shell
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

Create a GPG key if you don't already have one:

```shell
gpg --full-generate-key
```

When prompted:

    Select the default key type.
    Select the default key size, or use 4096.
    Choose an expiration period (0=no expiration).
    Enter your real name.
    Enter your email address.
    Enter a passphrase when prompted.

You can generate a strong password with:

```shell
openssl rand -base64 32
```

Find your GPG key ID:

```shell
gpg --list-secret-keys --keyid-format LONG
```

The key ID will look similar to:

```shell
sec   rsa3072/ABCDEF1234567890 2026-08-24 [SC]
```

Initialize password store using your GPG key ID:

```shell
pass init ABCDEF1234567890
```

Initialize the password store using the key ID:

```shell
pass init <gpg-id>
```

Configure GCM to use the GPG credential store:

```shell
git config --global credential.credentialStore gpg
```

Verify the configured credential store:

```shell
git config --global --get credential.credentialStore
```

It should output:

```shell
gpg
```

Then clone the repository:

```shell
git clone https://dev.azure.com/companyName/projectName/_git/repo-name
```

GCM will prompt for Microsoft/Azure DevOps authentication. After authentication, GCM will securely store the resulting credential in the GPG-encrypted pass store. Subsequent git pull, git fetch, and git push operations should not require you to authenticate again.

#### Option 2: PAT in ~/.bash_profile

This approach is simpler and works well on headless machines, but is less secure because the PAT is stored as plaintext in your shell profile and is available to processes launched from that shell.

Add the PAT to `~/.bash_profile`:

```shell
export AZURE_DEVOPS_PAT="your-ado-pat"
```

Protect the profile:

```shell
chmod 600 ~/.bash_profile
```

Create `~/.git-credential-azure`:

```shell
#!/usr/bin/env bash

if [[ "$1" == "get" ]]; then
    echo "protocol=https"
    echo "host=dev.azure.com"
    echo "username=pat"
    echo "password=$AZURE_DEVOPS_PAT"
fi
```

Protect the credential helper:

```shell
chmod 700 ~/.git-credential-azure
```

Configure the PAT helper specifically for Azure DevOps:

```shell
git config --global credential.https://dev.azure.com.helper ~/.git-credential-azure
```

Since the PAT is provided by the environment variable, GCM does not need to store the credential:

```shell
git config --global credential.credentialStore none
```

Reload your profile:

```shell
source ~/.bash_profile

# Or run exec $SHELL
```

Verify the credential-helper configuration:

```shell
git config --global --get-regexp 'credential.*helper'
```

You should see something similar to:

```shell
credential.helper /usr/local/bin/git-credential-manager
credential.https://dev.azure.com.helper ~/.git-credential-azure
```

You can then clone without being prompted for the PAT:

```shell
git clone https://dev.azure.com/companyName/projectName/_git/repo-name
```

The same setup applies to subsequent git pull, git fetch, and git push operations against Azure DevOps.

Do not replace the global credential helper:

```shell
# Don't do this
git config --global credential.helper ~/.git-credential-azure
```

That can prevent GCM from working normally for other Git hosts. Instead, configure the PAT helper only for Azure DevOps:

```shell
git config --global credential.https://dev.azure.com.helper ~/.git-credential-azure
```
