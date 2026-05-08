# Issues <!-- omit in toc -->

I use [git-bug](https://github.com/git-bug/git-bug) to keep the issues for this repository portable. When I move this repository to another remote, `git-bug` allows me to move issues with it.

> [!NOTE]
> Check the [`git-bug` docs](https://github.com/git-bug/git-bug/tree/trunk/doc) for more detailed documentation.

## Setup

- Install `git-bug` ([git-bug install docs](https://github.com/git-bug/git-bug/blob/trunk/INSTALLATION.md))
  - [Github releases](https://github.com/git-bug/git-bug/releases)
  - The [`install-git-bug.sh` script](../linux/bash/installs/git-bug/install-git-bug.sh)

## Usage

- Create a [bridge](https://github.com/git-bug/git-bug/blob/trunk/doc/usage/third-party.md)
  - `git-bug` will detect your current remote origin and automatically configure a bridge
    - If you get errors trying to use the automatic setup, create a bridge manually
  - For interacting with issues in other repositories, you can create a bridge with `git bug bridge new` to start the wizard
- Use one of the [`git-bug` interfaces](https://github.com/git-bug/git-bug/blob/trunk/doc/usage/interfaces.md)
  - Use `git bug termui` to start [`git-bug` TUI app](https://github.com/git-bug/git-bug/blob/trunk/doc/usage/interfaces.md#tui)
  - Use `git bug webui` to start the [web server for `git-bug`](https://github.com/git-bug/git-bug/blob/trunk/doc/usage/interfaces.md#web-ui)
- Push issues with `git bug bridge push [bridge-name]`
- Pull issues with `git bug bridge pull [bridge-name]`

