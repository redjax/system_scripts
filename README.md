# System Scripts <!-- omit in toc -->

<!-- Git Badges -->
<p align="center">
  <a href="https://github.com/redjax/system_scripts">
    <img alt="Created At" src="https://img.shields.io/github/created-at/redjax/system_scripts">
  </a>
  <a href="https://github.com/redjax/system_scripts/commit">
    <img alt="Last Commit" src="https://img.shields.io/github/last-commit/redjax/system_scripts">
  </a>
  <a href="https://github.com/redjax/system_scripts/commit">
    <img alt="Commits this year" src="https://img.shields.io/github/commit-activity/y/redjax/system_scripts">
  </a>
  <a href="https://github.com/redjax/system_scripts">
    <img alt="Repo size" src="https://img.shields.io/github/repo-size/redjax/system_scripts">
  </a>
  <!-- ![GitHub Latest Release](https://img.shields.io/github/release-date/redjax/system_scripts) -->
  <!-- ![GitHub commits since latest release](https://img.shields.io/github/commits-since/redjax/system_scripts/latest) -->
  <!-- ![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/redjax/system_scripts/tests.yml) -->
</p>

My collection of system scripts, broken down by OS. As I write scripts I use across multiple machines, I add the generic version here for re-use. Some scripts, like [Windows package manager scripts](./windows/powershell/installs/packagemanagers/), are meant to be run as-is, and use other files in the repository for execution.

Scripts cover a range of topics & purposes, from Azure and Active Directory, to backup & installation scripts, system configurations, & demo/proof-of-concept scripts.

## ⚠️ Disclaimer <!-- omit in toc -->

These are my own scripts I've written for my personal use, or for specific work I do. They may or may not be useful to you, but read each script carefully before you run it.

These are scripts I run on my own machines, and I am not interested in damaging my devices or infecting them with malware. That being said, many of the scripts download executables or other scripts from locations on the Internet. Care must be taken if you use any of the scripts in this repository, and if you find any issues with any of the scripts, please open an issue! :)

## Table of Contents <!-- omit in toc -->

- [Reporting problems](#reporting-problems)
- [Description](#description)
- [Directories](#directories)

## Reporting problems

Found a problem? [Open an issue](https://github.com/redjax/system_scripts/issues/new). I don't have a template for submitting issues, but please include at least the following:

- The script or portion of the repository you found a problem with
- Basic details about your hardware
  - OS
  - CPU type (x86_64, ARM32/ARM64, etc)
    - You can optionally (helpfully 😀) include your make/model
  - A description of the problem
  - Any screenshots/error messages you can include that would help with debugging.

## Description

As I write/find scripts I want to use across machines (work or personal), I add them to this repository. Scripts can be copy/pasted from the Github repository, or the whole repository can be cloned & scripts can be launched from the cloned repository.

As of 12/23/2024, the repository is very Windows script heavy. I have a number of Bash scripts to add, but they are scattered across other repositories and machines and I have spent most of the effort putting this repository together with new Windows scripts I write.

## Directories

- [`repo_scripts/`](./repo_scripts)
  - Scripts meant to be run from the repository root, i.e. `./repo_scripts/script_name.sh/ps1/...`
- [`windows/`](./windows/)
  - [`Powershell`](./windows/powershell/) and [`Batch`/`CMD`](./windows/batch/) scripts.
  - Includes application installs/uninstalls, automation scripts, maintenance scripts, and more
- [`linux/`](./linux/)
  - Scripts (mostly [Bash](./linux/bash/)) for Linux
