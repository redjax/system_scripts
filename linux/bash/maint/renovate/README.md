# Renovate Scripts <!-- omit in toc -->

[Renovate](https://mend.io/renovate) is a tool for automating dependency updates. It works with [a range of platforms](https://docs.renovatebot.com/modules/platform/), and is relatively simple to [configure](https://docs.renovatebot.com/config-overview/). It will open pull requests with dependency updates, and can optionally keep track of updates in an issue.

## Table of Contents <!-- omit in toc -->

- [Setup](#setup)
  - [Github Setup](#github-setup)
- [Configuration](#configuration)
  - [Repository-local renovate.json](#repository-local-renovatejson)
    - [Default/minimal](#defaultminimal)
    - [Python](#python)
    - [Go](#go)
    - [Github Actions](#github-actions)
    - [Docker](#docker)
    - [Terraform](#terraform)
    - [Node](#node)
- [Links](#links)

## Setup

### Github Setup

On Github, you must create a fine-grained token to grant Renovate permissions to operate on your repositories. You should create 2 tokens, a "read only" version with minimal read access, and a "read/write" token that Renovate will use to manage issues, pull requests, etc.

Create tokens for the following env vars:

- `RENOVATE_GITHUB_COM_TOKEN`: Read-only access
  - For optimal security, grant access to specific repositories, only the ones Renovate will interact with.
  - `Contents`: Read-only
  - `Metadata`: Read-only

- `RENOVATE_TOKEN`: Read/write access
  - `Contents`: Read and write
  - `Pull requests`: Read and write
  - `Metadata`: Read-only
  - `Commit statuses`: Read and write
  - `Workflows`: Read and write, if you want Renovate to update files under `.github/workflows/` and create PRs that touch workflow files

## Configuration

You will need to [configure your Renovate server](https://docs.renovatebot.com/config-overview/) according to your individual needs. Do this by copying the [example `.config.js`](./config/example.config.js) to `config/config.js` and edit it. You can also create separate configs for specific tasks, like `config/docker.config.js` or `config/python-gh-actions.config.js` (for Python + Github Actions). But it's usually easier to manage all tools in 1 config.

When you copy the example configuration file, make sure you set a value for `gitAuthor` and `repositories`.

### Repository-local renovate.json

Individual repositories can override Renovate's default config by putting a `renovate.json` file at the root of the repository.

#### Default/minimal

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true
}
```

#### Python

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true,
  "enabledManagers": ["pep621", "pip_requirements", "pip-compile", "poetry", "pre-commit"],
  "packageRules": [
    {
      "matchManagers": ["pep621"],
      "groupName": "Python dependencies"
    }
  ]
}
```

#### Go

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true,
  "enabledManagers": ["gomod"],
  "packageRules": [
    {
      "matchManagers": ["gomod"],
      "groupName": "Go dependencies"
    }
  ]
}
```

#### Github Actions

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true,
  "enabledManagers": ["github-actions"],
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "groupName": "GitHub Actions"
    }
  ]
}
```

#### Docker

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true,
  "enabledManagers": ["dockerfile", "docker-compose"],
  "packageRules": [
    {
      "matchManagers": ["dockerfile", "docker-compose"],
      "groupName": "Docker dependencies"
    }
  ]
}
```

#### Terraform

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true,
  "enabledManagers": ["terraform", "terraform-version", "terragrunt", "terragrunt-version", "tflint-plugin"],
  "packageRules": [
    {
      "matchManagers": ["terraform", "terragrunt"],
      "groupName": "Terraform"
    }
  ]
}
```

#### Node

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "dependencyDashboard": true,
  "enabledManagers": ["npm", "nvm", "mise"],
  "packageRules": [
    {
      "matchManagers": ["npm"],
      "groupName": "Node dependencies"
    }
  ]
}
```


## Links

- [Renovate home](https://mend.io/renovate)
- [Renovate Github](https://github.com/renovatebot/renovate)
- [Renovate docs](https://docs.renovatebot.com)
