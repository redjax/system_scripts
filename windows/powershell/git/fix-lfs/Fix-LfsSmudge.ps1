## Script to repair a git repo using LFS.
#
#  Fixes missing LFS files by fetching them from the remote and restoring them in the working tree.
#  Usage examples:
#    .\Repair-GitLfs.ps1 -RepoPath "C:\MyRepo -RepairAllMissingLfs
#    .\Repair-GitLfs.ps1 -RepoPath "C:\MyRepo -FileToRepair "path/to/file.bin"
param(
    [string]$RepoPath = ".",
    [string]$RemoteName = "origin",
    [string]$FileToRepair = "",
    [switch]$RepairAllMissingLfs,
    [switch]$PullAfterFix
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "== $Message ==" -ForegroundColor Cyan
}

function Invoke-Git([string]$Args, [switch]$IgnoreExitCode) {
    $output = & git $Args 2>&1
    $exitCode = $LASTEXITCODE
    if (-not $IgnoreExitCode -and $exitCode -ne 0) {
        throw "git $Args failed with exit code $exitCode`n$output"
    }
    return , $output
}

function Convert-AdoRemoteToLfsUrl([string]$RemoteUrl) {
    ## Handles Azure DevOps SSH:
    #  git@ssh.dev.azure.com:v3/{org}/{project}/{repo}
    $sshPattern = '^git@ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/([^/\s]+)$'
    if ($RemoteUrl -match $sshPattern) {
        $org = $Matches[1]
        $project = $Matches[2]
        $repo = $Matches[3]
        return "https://dev.azure.com/$org/$project/_git/$repo/info/lfs"
    }

    ## Handles Azure DevOps HTTPS:
    #  https://dev.azure.com/{org}/{project}/_git/{repo}
    $httpsPattern = '^https://dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/\s]+)$'
    if ($RemoteUrl -match $httpsPattern) {
        $org = $Matches[1]
        $project = $Matches[2]
        $repo = $Matches[3]
        return "https://dev.azure.com/$org/$project/_git/$repo/info/lfs"
    }

    return $null
}

function Is-LfsTrackedFile([string]$Path) {
    $attr = Invoke-Git "check-attr filter -- ""$Path""" -IgnoreExitCode
    foreach ($line in $attr) {
        if ($line -match ':\s*filter:\s*lfs\s*$') {
            return $true
        }
    }
    return $false
}

Push-Location $RepoPath
try {
    Write-Step "Validating repository"
    Invoke-Git "rev-parse --is-inside-work-tree" | Out-Null

    Write-Step "Current branch/status"
    Invoke-Git "status --short --branch" | ForEach-Object { Write-Host $_ }

    Write-Step "Inspecting LFS environment"
    $lfsEnv = Invoke-Git "lfs env"
    $lfsEnv | Select-String "Endpoint=|BasicTransfersOnly=|AccessDownload=|DownloadTransfers=" | ForEach-Object { Write-Host $.Line }

    Write-Step "Applying robust LFS settings (local repo only)"
    ## This is broadly safe and often helps in flaky environments.
    Invoke-Git "config --local lfs.basictransfersonly true" | Out-Null

    ## If this repo looks like Azure DevOps and endpoint is problematic, set lfs.url.
    $remoteUrl = (Invoke-Git "config --get remote.$RemoteName.url" -IgnoreExitCode | Select-Object -First 1)
    if (-not $remoteUrl) {
        throw "Could not resolve remote URL for '$RemoteName'."
    }

    $adoLfsUrl = Convert-AdoRemoteToLfsUrl $remoteUrl
    if ($adoLfsUrl) {
        Write-Host "Detected Azure DevOps remote. Setting local lfs.url to:"
        Write-Host $adoLfsUrl
        Invoke-Git "config --local lfs.url ""$adoLfsUrl""" | Out-Null
    }
    else {
        Write-Host "Remote is not Azure DevOps format; leaving lfs.url unchanged."
    }

    Write-Step "Finding files to repair"
    $targets = New-Object System.Collections.Generic.List[string]

    if ($FileToRepair) {
        $targets.Add($FileToRepair)
    }
    elseif ($RepairAllMissingLfs) {
        ## Look for tracked files deleted in working tree (porcelain format: ' D path')
        $statusLines = Invoke-Git "status --porcelain"
        foreach ($line in $statusLines) {
            if ($line -match '^\sD\s+(.+)$') {
                $path = $Matches[1].Trim()
                if (Is-LfsTrackedFile $path) {
                    $targets.Add($path)
                }
            }
        }
    }
    else {
        ## Default behavior: try to repair all missing LFS files
        $statusLines = Invoke-Git "status --porcelain"
        foreach ($line in $statusLines) {
            if ($line -match '^\sD\s+(.+)$') {
                $path = $Matches[1].Trim()
                if (Is-LfsTrackedFile $path) {
                    $targets.Add($path)
                }
            }
        }
    }

    $targets = $targets | Sort-Object -Unique

    if (-not $targets -or $targets.Count -eq 0) {
        Write-Host "No missing LFS-tracked files detected."
    }
    else {
        Write-Host "Will repair these LFS files:"
        $targets | ForEach-Object { Write-Host " - $" }

        Write-Step "Fetching and restoring files"
        foreach ($path in $targets) {
            Write-Host "Fetching LFS object for: $path"
            Invoke-Git "lfs fetch $RemoteName --include=""$path"" --exclude=""" | Out-Null

            Write-Host "Restoring file: $path"
            Invoke-Git "restore --worktree -- ""$path""" | Out-Null
        }
    }

    Write-Step "Final status"
    Invoke-Git "status --short --branch" | ForEach-Object { Write-Host $_ }

    if ($PullAfterFix) {
        Write-Step "Pulling latest (fast-forward only)"
        Invoke-Git "pull --ff-only"
        Write-Host "Pull completed."
    }

    Write-Step "Done"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    Pop-Location
}

