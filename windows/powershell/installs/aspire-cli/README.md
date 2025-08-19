# Aspire CLI <!-- omit in toc -->

Install script for the Microsoft .NET Aspire CLI tool.

## Table of Contents <!-- omit in toc -->

- [Requirements](#requirements)
- [Usage](#usage)
  - [Basic Installation](#basic-installation)
  - [Parameters](#parameters)
  - [Quality Options](#quality-options)
  - [Examples](#examples)
  - [Notes](#notes)
- [Links](#links)

## Requirements

- PowerShell 5.1 or later
- Internet connection to download the installation script

## Usage

This PowerShell script provides a convenient way to install the .NET Aspire CLI with various customization options. The script dynamically builds and executes the official Aspire installation command based on your specified parameters.

### Basic Installation

```powershell
## Install to default location (%USERPROFILE%\.aspire\bin)
.\install-aspirecli.ps1
```

### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `InstallPath` | String | Custom installation directory | `$env:USERPROFILE\.aspire\bin` |
| `VerboseOutput` | Switch | Enable verbose output during installation | `$false` |
| `Version` | String | Install a specific version (e.g., "9.4") | Latest |
| `Quality` | String | Build quality: `release`, `staging`, or `dev` | `release` |

### Quality Options

- **`release`** - Latest stable release version (recommended for production)
- **`staging`** - Latest staging/release candidate version (for testing upcoming releases)
- **`dev`** - Latest development build from main branch (bleeding edge)

### Examples

```powershell
## Install latest release to default location
.\install-aspirecli.ps1

## Install to custom directory with verbose output
.\install-aspirecli.ps1 -InstallPath "C:\Tools\Aspire" -VerboseOutput

## Install a specific version
.\install-aspirecli.ps1 -Version "9.4"

## Install development build
.\install-aspirecli.ps1 -Quality "dev"

## Install staging build to custom location
.\install-aspirecli.ps1 -Quality "staging" -InstallPath "C:\Tools\Aspire"

## All options combined
.\install-aspirecli.ps1 -InstallPath "C:\Tools\Aspire" -Quality "dev" -VerboseOutput
```

### Notes

- The script will prompt for confirmation before executing the installation
- The installation command will be displayed before execution for transparency
- The script uses the official Microsoft Aspire installation script from `https://aspire.dev/install.ps1`

## Links

- [Aspire CLI install docs](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/setup-tooling?tabs=windows&pivots=vscode#-aspire-cli)

