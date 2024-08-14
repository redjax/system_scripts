<#
    .SYNOPSIS
    Helper methods for initializing a new Powershell module.

    .Description
    Accepts params or prompts the user for required fields, then creates a new Powershell module at the path
    this script was executed from.

    .EXAMPLE
    Add-NewPSModule -ModuleName "ExampleModule" -ModuleDescription "This is a description for the module" -ModuleAuthor "Your Name"

    .NOTES
    Version: 1.0
    Author: Jack Kenyon
    Creation Date: 07-22-2024
    Modified Date: 
    Purpose/Change: Init
    Link: 
#>

Param(
    [Switch]$Debug,
    [string]$CopyrightYear = (Get-Date).Year,
    [string]$ModuleName = $null,
    [string]$ModuleDescription = $null,
    [string]$ModuleVersion = '1.0',
    [string]$ModuleAuthor = $null,
    [string]$CompanyName = 'Embrace Pet Insurance'
)

If ( $Debug ) {
    ## Enable script debug messages if -Debug is passed
    $DebugPreference = 'Continue'
}
else {
    $DebugPreference = 'SilentlyContinue'
}

function Test-UserInputs {
    <#
        Validate script input params. Use $script:VarName to override global/script-scope values.
    #>

    If ( -Not $script:CopyrightYear ) {
        If ( $Debug ) {
            Write-Warning '-CopyrightYear is null.'
        }

        $script:CopyrightYear = Read-Host 'Please input a copyright year'
    }

    If ( -Not $script:ModuleName ) {
        If ( $Debug ) {
            Write-Warning '-ModuleName is null.'
        }
        
        $script:ModuleName = Read-Host 'Please input a module name'
    }

    If ( -Not $script:ModuleDescription ) {
        If ( $Debug ) {
            Write-Warning '-ModuleDescription is null.'
        }
        
        $script:ModuleDescription = Read-Host 'Please input a description of the module'
    }

    If ( -Not $script:ModuleVersion ) {
        If ( $Debug ) {
            Write-Warning '-ModuleVersion is null.'
        }
        
        $ModuleVersion = Read-Host 'Please input a version for the module, i.e. 1.0'
    }

    If ( -Not $script:CompanyName ) {
        If ( $Debug ) {
            Write-Warning '-CompanyName is null.'
        }
        
        $script:CompanyName = Read-Host 'Please input a company name'
    }

}

## Validate script params
Test-UserInputs

## Build copyright string
$CopyrightString = "$year"
If ( $ModuleAuthor ) {
    $CopyrightString = $CopyrightString + "$($ModuleAuthor)"
}

Write-Debug "Module name: $($ModuleName)"

## Create the module's top-level directory
New-Item -ItemType Directory -Name $ModuleName

# Create subdirectories
#    ModuleName
#    |___ ...
#    |___ ...
#    |___Private
#    |   |___ps1
#    |___ ...

## Create the module's Private\ps1 script dir
New-Item -Path "$PWD\$ModuleName\Private\ps1" -ItemType Directory -Force

# Create subdirectories
#    ModuleName
#    |___ ...
#    |___ ...
#    |___ ...
#    |___Public
#        |___ps1

## Create the module's Public\ps1 script dir
New-Item -Path "$PWD\$ModuleName\Public\ps1" -ItemType Directory -Force

# Create the script module
#    ModuleName
#    |___ ...
#    |___ TestModule.psm1

## Create module's manifest file ($ModuleName.psm1)
New-Item -Path "$PWD\$ModuleName\$ModuleName.psm1" -ItemType File

# Create the module manifest
#    ModuleName
#    |ModuleName.psd1
#    |___ ...

## Build module's manifest parameter mapping
$ModuleManifestParameters = @{
    Path          = "$PWD\$ModuleName\$ModuleName.psd1"
    Author        = $ModuleAuthor
    CompanyName   = $CompanyName
    Copyright     = "$($CopyrightString)"
    ModuleVersion = $ModuleVersion
    Description   = $ModuleSummary
    RootModule    = "$($ModuleName).psm1"
}

try {
    ## Build module manifest
    New-ModuleManifest @ModuleManifestParameters
}
catch {
    Write-Error "Unable to create new module. Details: $($_.Exception.Message)"
}
