# Git Credential Manager

Installs [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) on a Linux machine.

## Usage

### Azure DevOps

Create a Personal Access Token (PAT) in Azure DevOps. Configure GCM to use it with:

```shell
git config --global credential.azreposCredentialType pat
git config --global credential.credentialStore cache
git config --global credential.https://dev.azure.com.useHttpPath true
```

Clone repositories with `git clone https://dev.azure.com/companyName/projectName/_git/repo-name`.

#### Using PAT from Environment Variable

If you don't want to enter the PAT every time Git authenticates, you can store it in an environment variable. **Be aware that this means the PAT is stored as plaintext in your shell profile.**

Add the following to a file sourced when your shell starts, such as `~/.bash_profile`:

```shell
export AZURE_DEVOPS_PAT="your-ado-pat"
```

Protect the file (if you used something other than `~/.bash_profile`, enter that path instead):

```shell
chmod 600 ~/.bash_profile
```

Then create a file like `~/.git-credential-azure`:

```shell
#!/usr/bin/env bash

if [[ "$1" == "get" ]]; then
    echo "protocol=https"
    echo "host=dev.azure.com"
    echo "username=pat"
    echo "password=$AZURE_DEVOPS_PAT"
fi
```

And tell GCM to use it:

```shell
chmod 700 ~/.git-credential-azure
git config --global credential.https://dev.azure.com.helper ~/.git-credential-azure
```

Verify the configuration:

```shell
git config --global --get-regexp 'credential.*helper'
```

You should see something like:

```shell
credential.helper /usr/local/bin/git-credential-manager
credential.https://dev.azure.com.helper ~/.git-credential-azure
```

You should then be able to clone without being prompted for the PAT:

```shell
git clone https://dev.azure.com/companyName/projectName/_git/repo-name
```
