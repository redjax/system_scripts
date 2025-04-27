[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "The remote host to copy from")]
    $RemoteHost = $null,
    [Parameter(Mandatory = $false, HelpMessage = "The remote path to copy from")]
    $RemotePath = $null,
    [Parameter(Mandatory = $false, HelpMessage = "The local path to copy to")]
    $LocalPath = $null
)

## Validate inputs
if ( $null -eq $RemoteHost -or $null -eq $RemotePath -or $null -eq $LocalPath ) {
    Write-Error "Missing required parameters. Please provide a remote host, remote path, and local path."
    throw
}

## Test if scp is installed
if ( -not ( Get-Command scp -ErrorAction SilentlyContinue ) ) {
    Write-Error "scp command not found. Please install OpenSSH."
    throw
}

## Copy from remote
Write-Information "Copying from $($RemoteHost):$($RemotePath) to $($LocalPath)"
try {
    ## Copy path from remote
    scp -r "$($RemoteHost):$($RemotePath)" "$($LocalPath)"

    Write-Information "Successfully copied from $($RemoteHost):$($RemotePath) to $($LocalPath)"
}
catch {
    Write-Error "Error copying from $($RemoteHost):$($RemotePath) to $($LocalPath). Details: $($_.Exception.Message)"
    throw
}
