<#
    .SYNOPSIS
    Install the .NET Aspire CLI with customizable options.

    .DESCRIPTION
    This script dynamically builds and executes the Aspire CLI installation command
    based on the provided parameters. It supports custom installation paths, 
    specific versions, and verbose output.

    .PARAMETER InstallPath
    The path where the Aspire CLI binary will be installed. 
    Default: $env:USERPROFILE\.aspire\bin

    .PARAMETER VerboseOutput
    Enable verbose output during installation.

    .PARAMETER Version
    Install a specific version of Aspire CLI (e.g., '9.4').

    .PARAMETER Quality
    Quality of the Aspire CLI build to install:
    - 'release' = Latest stable release version (default)
    - 'staging' = Latest staging/release candidate version
    - 'dev' = Latest development build from main branch

    .EXAMPLE
    .\install-aspirecli.ps1
    Installs Aspire CLI to the default location using the latest release.

    .EXAMPLE
    .\install-aspirecli.ps1 -InstallPath "C:\Tools\Aspire" -VerboseOutput
    Installs Aspire CLI to a custom path with verbose output.

    .EXAMPLE
    .\install-aspirecli.ps1 -Version "9.4"
    Installs a specific version of Aspire CLI.

    .EXAMPLE
    .\install-aspirecli.ps1 -Quality "dev"
    Installs the latest development build of Aspire CLI.

    .EXAMPLE
    .\install-aspirecli.ps1 -Quality "staging"
    Installs the latest staging/release candidate build of Aspire CLI.
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory = $false, HelpMessage = "The path where the Aspire CLI binary will be installed. Default: `$env:USERPROFILE\.aspire\bin")]
  [string]$InstallPath,
  [Parameter(Mandatory = $false, HelpMessage = "Enable verbose output during install.")]
  [switch]$VerboseOutput,
  [Parameter(Mandatory = $false, HelpMessage = "Install a specific version of Aspire CLI, i.e. '9.4'")]
  [string]$Version,
  [Parameter(Mandatory = $false, HelpMessage = "Quality of the Aspire CLI build to install. 'release' = latest release, 'staging' = latest staging/RC, 'dev' = latest development build")]
  [ValidateSet("release", "staging", "dev")]
  [string]$Quality
)

## Base command to download and execute the Aspire install script
$BaseCommand = "Invoke-Expression `"& { `$(Invoke-RestMethod https://aspire.dev/install.ps1) }"

## Build parameter string based on provided arguments
$Parameters = @()

if ($InstallPath) {
    $Parameters += "-InstallPath '$InstallPath'"
}

if ($VerboseOutput) {
    $Parameters += "-Verbose"
}

if ($Version) {
    $Parameters += "-Version '$Version'"
}

if ($Quality) {
    $Parameters += "-Quality '$Quality'"
}

## Combine base command with parameters
if ($Parameters.Count -gt 0) {
    $FullCommand = $BaseCommand + " " + ($Parameters -join " ") + "`""
} else {
    $FullCommand = $BaseCommand + "`""
}

## Display the command that will be executed
Write-Host "Executing Aspire CLI installation command:" -ForegroundColor Cyan
Write-Host $FullCommand -ForegroundColor Yellow
Write-Host ""

## Confirm before execution
$Confirmation = Read-Host "Do you want to proceed with the installation? (Y/N)"
if ( $Confirmation -match "^[Yy]" ) {
    try {
        Write-Host "Installing Aspire CLI..." -ForegroundColor Green
        Invoke-Expression $FullCommand
        Write-Host "Aspire CLI installation completed successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to install Aspire CLI: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Host "Installation cancelled by user." -ForegroundColor Yellow
    exit 0
}