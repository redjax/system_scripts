#Requires -RunAsAdministrator
<#
    .SYNOPSIS
    Post-install setup script for Docker on Windows.

    .DESCRIPTION
    This script performs post-installation tasks for Docker on Windows, including enabling the Docker service,
    starting the service, and adding specified users to the `docker-users` group.

    .PARAMETER User
    User(s) to add to the `docker-users` group. Accepts multiple users as an array, i.e. -User "domain\user1" -User "user2".

    .EXAMPLE
    .\post-install-setup.ps1 -User "user1", "user2"
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, HelpMessage = "User(s) to add to the docker-users group.", ValueFromPipeline = $true)]
    [string[]]$User
)

# Enable and start Docker service
Write-Host "Enabling and starting Docker service..." -ForegroundColor Cyan
try {
    dockerd --register-service
    Start-Service docker
} catch {
    Write-Error "Failed to enable/start Docker service: $($_.Exception.Message)"
    exit 1
}

if (-not $User -or $User.Count -eq 0) {
    Write-Error "At least one user must be specified with -User."
    exit 1
}

# Add specified users to docker-users group
ForEach ( $u in $User ) {
    Write-Host "Adding $u to docker-users group..." -ForegroundColor Cyan
    try {
        Add-LocalGroupMember -Group "docker-users" -Member $u
    } catch {
        Write-Error "Failed to add $($u): $($_.Exception.Message)"
        continue
    }

    Write-Host "$u has been added to docker-users group." -ForegroundColor Green
}

## Check if Docker is running
try {
    $dockerStatus = Get-Service docker
    if ($dockerStatus.Status -eq 'Running') {
        Write-Host "Docker is running." -ForegroundColor Green
    } else {
        Write-Host "Docker service is not running. Please check the service status." -ForegroundColor Yellow
    }
} catch {
    Write-Error "Failed to retrieve Docker service status: $($_.Exception.Message)"
}
