<#
    .SYNOPSIS
    Disables the Windows Recall feature.

    .DESCRIPTION
    Disables the Windows Recall feature via the "Turn Windows Features On or Off" control panel.

    .EXAMPLE
    Disable-WindowsRecallFeature
#>

Write-Host "Attempting to disable Windows Recall feature" -ForegroundColor Cyan

try {
    Disable-WindowsOptionalFeature -Online -FeatureName "Recall"
    Write-Host "Successfully disabled Windows Recall feature" -ForegroundColor Green
} catch {
    Write-Error "Error disabling Windows Recall feature. Details: $($_.Exception.Message)"
    throw $_
}
