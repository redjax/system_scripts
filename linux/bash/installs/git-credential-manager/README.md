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

You can also store the PAT in an environment variable, although this is not recommended as it's essentially storing the plaintext password in your profile. To do this, edit a file sourced by `.bashrc`, i.e. `~/.bash_profile`, and add this environment variable:

```shell
export AZURE_DEVOPS_PAT="your-ado-pat"
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
git config --global credential.helper ~/.git-credential-azure
```

Make sure the `.bash_profile` file has the correct permissions:

```shell
chmod 600 ~/.bash_profile
```
