<#
    .SYNOPSIS
    Disables Windows Recall via registry.

    .DESCRIPTION
    Disables Windows Recall via registry. Checks for presence of key and creates if missing, then sets value to 0.

    .EXAMPLE
    Disable-RecallViaRegistry
#>

function Disable-RecallViaRegistry {
    <#
        .SYNOPSIS
        Disables Windows Recall via registry.

        .DESCRIPTION
        Disables Windows Recall via registry. Checks for presence of key and creates if missing, then sets value to 0.

        .EXAMPLE
        Disable-RecallViaRegistry
    #>

    ## Path to folder in registry where key will be created
    [string]$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
    ## Name of key to be created
    [string]$name = "AllowRecallEnablement"
    ## Value of key to be created
    [int]$value = 0

    ## Check if key path exists & create if not
    Write-Host "Checking for presence of Windows Recall registry key at $regPath" -ForegroundColor Cyan
    try {
        if (-not (Test-Path -Path $regPath)) {
            Write-Warning "Windows Recall registry key was not found at path: $regPath. Attempting to create path."
            try {
                New-Item -Path $regPath -Force | Out-Null
                Write-Host "Successfully created Windows Recall registry key at path: $regPath" -ForegroundColor Green
            } catch {
                Write-Error "Unable to create Windows Recall registry key at path: $regPath. Details: $($_.Exception.Message)"
                throw $_
            }
        }
    } catch {
        Write-Error "Error checking for Windows Recall registry key. Details: $($_.Exception.Message)"
        throw $_
    }

    ## Check for the presence of the AllowRecallEnablement value, create if missing, and set to 0
    try {
        $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
        if ($null -eq $props.PSObject.Properties[$name]) {
            Write-Host "$name value not found. Creating and setting to $value." -ForegroundColor Yellow
            try {
                New-ItemProperty -Path $regPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
                Write-Host "$name value created and set to $value." -ForegroundColor Green
            } catch {
                Write-Error "Error creating $name value. Details: $($_.Exception.Message)"
                throw $_
            }
        } else {
            Write-Host "$name value exists. Setting to $value." -ForegroundColor Cyan
            try {
                Set-ItemProperty -Path $regPath -Name $name -Value $value
                Write-Host "$name value set to $value." -ForegroundColor Green
            } catch {
                Write-Error "Error setting $name value. Details: $($_.Exception.Message)"
                throw $_
            }
        }
    } catch {
        Write-Error "Error handling $name value. Details: $($_.Exception.Message)"
        throw $_
    }

    Write-Host "Disabled Windows Recall via registry." -ForegroundColor Green
}

try {
    Disable-RecallViaRegistry
} catch {
    Write-Error "Error disabling Windows Recall via registry. Details: $($_.Exception.Message)"
    throw $_
}
