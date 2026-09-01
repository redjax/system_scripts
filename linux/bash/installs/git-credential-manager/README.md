# Git Credential Manager

Installs [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) on a Linux machine.

## Usage

### Azure DevOps

Clone repositories using the HTTPS URL, i.e.: `git clone https://dev.azure.com/companyName/projectName/_git/repo-name`.

#### PAT in ~/.bash_profile

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

Verify that the credential helper can retrieve the PAT without displaying it, the output should contain protocol, host, username, and password:

```shell
printf "protocol=https\nhost=dev.azure.com\n\n" | ~/.git-credential-azure get
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

> [!NOTE]
> Storing a PAT in a file and sourcing it for GCM like this is not very secure. You will see warnings when running git commands, like:
>
> ```shell
> fatal: No credential store has been selected
>
> Set the GCM_CREDENTIAL_STORE environment variable or the credential.credentialStore Git configuration setting to one of the following options:
> 
>   secretservice  : freedesktop.org Secret Service (requires graphical interface)
>   gpg            : GNU `pass` compatible credential storage (requires GPG and `pass`)
>   cache          : Git's in-memory credential cache
>   plaintext      : store credentials in plain-text files (UNSECURE)
>   none           : disable internal credential storage
>
> See https://aka.ms/gcm/credstores for more information.
> ```
>
> To resolve these errors, run these commands to tell Git not to invoke the global GCM helper for `dev.azure.com`:
>
> ```shell
> git config --global credential.https://dev.azure.com.helper ""
> git config --global credential.https://dev.azure.com.helper ~/.git-credential-azure
> ```
