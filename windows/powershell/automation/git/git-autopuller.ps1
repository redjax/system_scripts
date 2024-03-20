Param(
    [String]$RepositoryPath,
    [String]$LogOutputDir = 'C:\logs\git-autopuller',
    [Switch]$Debug,
    [Switch]$Log
    
)

# Ensure log output file exists
if ( $Log ) {
    if ( $Debug ) {
        Write-Host 'Start log transcript' -ForegroundColor Magenta
    }

    ## Automatically generate a unique logfile each run
    Start-Transcript -OutputDirectory $LogOutputDir 'Debug'
}


# Check if repos$RepositoryPath parameter is provided
if ( -Not $RepositoryPath ) {
    Write-Error 'No repository path specified. Please provide the -RepositoryPath parameter.'
    exit 1
}



# Store the current directory
$CurrentDirectory = Get-Location

function Reset-PathCWD() {
    param(
        [String]$OriginalPath = $CurrentDirectory
    )

    if ( $Debug ) {
        Write-Host "[DEBUG] Resetting path to '$($OriginalPath)'" -ForegroundColor Magenta
    }

    try {
        # Set location back to the original directory
        Set-Location -Path $OriginalPath
    }
    catch {
        Write-Host "[WARNING] Unable to reset path to $($OriginalPath). Details: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Change directory to the repository
Set-Location $RepositoryPath

# Fetch all remote branches
try {
    git fetch --all
}
catch {
    Write-Warning "[ERROR] Error fetching all git branches. Details: $($_.Exception.message)"
}

# Get a list of all branches (local and remote)
$GitBranches = git branch -a | ForEach-Object { $_.Trim() }

# Loop through each branch
ForEach ( $GitBranch in $GitBranches ) {
    # Extract the branch name
    $GitBranchName = $GitBranch -Replace '^remotes/origin/|^\*|^\s+', ''

    # Skip if it's a remote HEAD or other non-branch reference
    if ($GitBranch -Match '^remotes/origin/HEAD' -Or $GitBranch -Match '->') {
        continue
    }

    # Check if the branch is a remote branch
    if ( $GitBranch -Match '^remotes/origin/' ) {
        # Check if the branch already exists locally
        if ( -Not ( git branch --list $GitBranchName ) ) {
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
# Set-Location -Path $CurrentDirectory
Reset-PathCWD

if ( $Log ) {
    if ( $Debug ) {
        Write-Host '[DEBUG] Stopping transaction' -ForegroundColor Magenta
    }

    Stop-Transcript
}