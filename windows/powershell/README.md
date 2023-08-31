# Powershell

Collection of Powershell scripts for various tasks.

## Notes

### Check admin

Use the code block below to check if the user who launched a script is an admin user. Useful for exiting a script early when a condition won't be met because the user is not an Administrator.

```
param(
    [Boolean]$Debug = $true
)

## Get identity from Windows
$windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()

function Get-AdminStatus {

    $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($windowsIdentity)
    ## Check if identity is an admin
    $isAdmin = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if ( $debug -eq $true ) {
        if ( $isAdmin -eq $true ) {
            Write-Host "User [$($windowsIdentity.Name)] is an Admin"
        }
        else {
            Write-Host "User [$($windowsIdentity.Name)] is not an Admin"
        }        
    }

    return $isAdmin

}

## Check if a user is an administrator
$adminStatus = Get-AdminStatus

if ( $adminStatus -eq $true ) {
    Write-Host "User [$($windowsIdentity.Name)] is an Administrator."
} else {
    Write-Host "User [$($windowsIdentity.Name)] is not an Administrator."
}

```

### Powershell approved verbs

[Approved verbs documentation](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.3)
