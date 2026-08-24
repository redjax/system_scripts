# Git Credential Manager

Installs [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) on a Linux machine.

## Usage

### Azure DevOps

Create a Personal Access Token (PAT) in Azure DevOps. Configure GCM to use it with:

```shell
git config --global credential.azreposCredentialType pat
git config --global credential.https://dev.azure.com.useHttpPath true
```

Clone repositories with `git clone https://dev.azure.com/companyName/projectName/_git/repo-name`.

#### Option 1: Secure credential storage (recommended)
With this approach, the PAT is not stored in your shell profile or an environment variable. GCM stores the credential using a supported credential store.

For a headless Linux machine, GCM can use GPG/pass for persistent encrypted credential storage.

Configure GCM to use the GPG credential store:

```shell
git config --global credential.credentialStore gpg
```

Then clone the repository:

```shell
git clone https://dev.azure.com/companyName/projectName/_git/repo-name
```

GCM will prompt for authentication and securely store the credential for subsequent Git operations.

    Note: The gpg credential store requires GPG and pass to be installed and configured.

Verify the configured credential store:

```shell
git config --global --get credential.credentialStore
```

It should output:

```shell
gpg
```

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
