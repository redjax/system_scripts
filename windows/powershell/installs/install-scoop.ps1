Param(
    [switch]$Debug,
    [switch]$DryRun
)

try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
} catch {
    Write-Error "Failed to set powershell execution policy to RemoteSigned."
    Write-Error "Exception details: $($exc.Message)"
    exit 1
}

If ( $Debug) {
    ## enable powershell logging
    $DebugPreference = "Continue"
}

If ( $DryRun ) {
    Write-Host "-DryRun enabled. Actions will be described, instead of taken. Messages will appear in purple where a live action would be taken." -ForegroundColor Magenta
}

function Install-ScoopCli {
    Write-Information "Install scoop from https://get.scoop.sh"
    Write-Host "Download & install scoop"

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would download & install scoop." -ForegroundColor Magenta
        return
    }
    
    try{
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    } catch {
        Write-Error "Failed to install scoop."
        Write-Error "Exception details: $($exc.Message)"
        exit 1
    }
}

function Configure-ScoopCli {
    Write-Host "Installing aria2 for accelerated downloads"

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would install aria2." -ForegroundColor Magenta
        Write-Host "[Dry RUN] Would enable scoop 'extras' bucket." -ForegroundColor Magenta
        Write-Host "[Dry RUN] Would disable aria2 warning." -ForegroundColor Magenta
        Write-Host "[Dry RUN] Would install git." -ForegroundColor Magenta

        return
    }

    try {
        scoop install aria2
    } catch {
        Write-Error "Failed to install aria2."
        Write-Error "Exception details: $($exc.Message)"
    }

    Write-Host "Enable scoop 'extras' bucket"
    try{
            scoop bucket add extras
    } catch {
        Write-Error "Failed to enable scoop 'extras' bucket."
        Write-Error "Exception details: $($exc.Message)"
    }

    Write-Host "Disable scoop warning when using aria2 for downloads"
    try {
        scoop config aria2-warning-enabled false
    } catch {
        Write-Error "Failed to disable aria2 warning."
        Write-Error "Exception details: $($exc.Message)"
    }

    Write-Host "Install git"
    try {
        scoop install git
    } catch {
        Write-Error "Failed to install git."
        Write-Error "Exception details: $($exc.Message)"
    }
}

Install-ScoopCli
Configure-ScoopCli
