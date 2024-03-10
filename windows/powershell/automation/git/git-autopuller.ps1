<#
    Automate pulling & fetching a git repository.
#>

param (
    [String]$GitDir,
    [Switch]$Debug
)

# Check if GitDir parameter is provided
if (-not $GitDir) {
    Write-Host 'Please provide the -GitDir parameter.'
    exit 1
}

# Ensure directory is a git repository
$gitPath = Join-Path $GitDir '.git'
if (-not (Test-Path -Path $gitPath -PathType Container)) {
    Write-Warning "Path '$GitDir' is not a git repository"
    exit 1
}

# Change directory to the specified Git directory
# Push-Location -Path $GitDir

function PullAllBranches {
    ## Loop over git branches from HEAD, run fetch & pull
    $branches = git branch -r | ForEach-Object { $_.Trim() }

    foreach ($branch in $branches) {
        # Extract branch name from remote reference
        $fixedBranch = $branch -replace '^origin/', ''

        # Check if the branch is a tracking branch
        if ($fixedBranch -match '^(\S+)\s+->') {
            $fixedBranch = $matches[1]
        }

        Write-Host "Pulling branch: $fixedBranch"
        
        # Checkout the branch and pull
        git checkout $fixedBranch | Out-Null
        git pull

        # Go back to the default branch
        git checkout -
    }
}

function Main() {
    Param(
        [String]$RepoDir = $GitDir
    )
    # Change directory to the specified Git directory
    Push-Location -Path $RepoDir

    ## Loop over all branches, fetch & pull
    PullAllBranches
    # Go back to the original location
    Pop-Location
}

Main
