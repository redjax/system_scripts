Param(
    [String]$RepositoryPath,
    [Switch]$Debug
)

# Check if repos$RepositoryPath parameter is provided
if (-not $RepositoryPath) {
    Write-Host 'Please provide the -RepositoryPath parameter.' -ForegroundColor Yellow
    exit 1
}

if ( -Not (Test-Path "$($RepositoryPath)" -PathType Container) ) {
    Write-Error "[ERROR] Could not find repository at path '$($RepositoryPath)'"

    exit 1
}

# Store the current directory
$CurrentDirectory = Get-Location

# Change directory to the repository
Set-Location (Join-Path -Path $RepositoryPath -ChildPath '')

Write-Host "Synchronizing repository at path '$($RepositoryPath)'" -ForegroundColor Green

# Fetch all remote branches
try {
    git fetch --all
}
catch {
    Write-Host "[ERROR] Error fetching all git branches. Details: $($_.Exception.message)" -ForegroundColor Yellow
}

# Get a list of all branches (local and remote)
$GitBranches = git branch -a | ForEach-Object { $_.Trim() }

# Loop through each branch
ForEach ($GitBranch in $GitBranches) {
    # Extract the branch name
    $GitBranchName = $GitBranch -replace '^remotes/origin/|^\*|^\s+', ''

    # Skip if it's a remote HEAD or other non-branch reference
    if ($GitBranch -match '^remotes/origin/HEAD' -or $GitBranch -match '->') {
        continue
    }

    # Check if the branch is a remote branch
    if ($GitBranch -match '^remotes/origin/') {
        # Check if the branch already exists locally
        if (-not (git branch --list $GitBranchName)) {
            # If the branch doesn't exist locally, create it by checking it out
            try {
                git checkout -b $GitBranchName remotes/origin/$GitBranchName
            }
            catch {
                Write-Host "[ERROr] Error checking out branch '$($GitBranchName)'. Details: $($_.Exception.message)" -ForegroundColor Yellow
            }
        }
        else {
            # If the branch exists locally, just fetch it
            try {
                git fetch origin $GitBranchName
            }
            catch {
                Write-Host "[ERROR] Error fetching branch '$($GitBranchName)'. Details: $($_.Exception.message)" -ForegroundColor Yellow
            }
        }
    }
    else {
        # For local branches, simply checkout and pull
        git checkout $GitBranchName
        
        try {
            git pull
        }
        catch {
            Write-Host "[ERROR] Error pulling branch '$($GitBranchName)'. Details: $($_.Exception.message)" -ForegroundColor Yellow
        }
    }
}

# Set location back to the original directory
Set-Location -Path $CurrentDirectory
