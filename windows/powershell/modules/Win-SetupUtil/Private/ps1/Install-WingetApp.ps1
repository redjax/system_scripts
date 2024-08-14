function Install-WingetApp {
    <# Install an app with winget #>
    [CmdletBinding()]
    Param(
        [PSCustomObject]$AppObject = $null
    )

    If ( -Not $AppObject ) {
        Write-Error "Missing an app object to install"
    }

    try {
        winget install --id "$($AppObject.id)"
    } catch {
        Write-Error "Unhandled exception installing app $($AppObject.Name). Details: $($_.Exception.message)"
    }

}