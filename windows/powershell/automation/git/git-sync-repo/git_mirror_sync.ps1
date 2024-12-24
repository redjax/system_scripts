# Set variable to path where script was launched from
$CWD = Get-Location

# Change to the directory where the script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $ScriptDir

# Set working directory for mirrors
$MirrorDir = Join-Path -Path $ScriptDir -ChildPath "repositories"
# File containing source and target repository pairs
$ReposFile = Join-Path -Path $ScriptDir -ChildPath "mirrors"

# Function to ensure git URL ends with .git
function Ensure-GitSuffix {
    param (
        [string]$RepoUrl
    )
    if (-not $RepoUrl.EndsWith(".git")) {
        $RepoUrl += ".git"
    }
    return $RepoUrl
}

# Function to clone a repository if it doesn't exist
function Clone-Repo {
    param (
        [string]$RepoUrl
    )
    $RepoName = [System.IO.Path]::GetFileNameWithoutExtension($RepoUrl)

    # Clone if the repository does not exist
    $RepoPath = Join-Path -Path $MirrorDir -ChildPath $RepoName
    if (-not (Test-Path -Path $RepoPath)) {
        Write-Host "Cloning repository $RepoUrl into $RepoPath"
        git clone --mirror $RepoUrl $RepoPath
    } else {
        Write-Host "Repository $RepoName already exists. Skipping clone."
    }
}

# Function to mirror repositories between source and target
function Push-NewRemote {
    param (
        [string]$SrcRepo,
        [string]$TargetRepo
    )
    $RepoName = [System.IO.Path]::GetFileNameWithoutExtension($SrcRepo)
    $RepoPath = Join-Path -Path $MirrorDir -ChildPath $RepoName

    Write-Host "Mirroring from $SrcRepo to $TargetRepo"

    Set-Location -Path $RepoPath

    # Ensure the remote target URL is set
    git remote set-url --push origin $TargetRepo

    # Push to target
    git push --mirror
}

# Main function
function Main {
    if (-not (Test-Path -Path $ReposFile)) {
        Write-Host "[ERROR] Repository file not found: $ReposFile"
        exit 1
    }

    # Read each line in the file
    Get-Content $ReposFile | ForEach-Object {
        $Line = $_.Trim()
        if (-not $Line -or $Line.StartsWith("##")) {
            return
        }

        $Parts = $Line -split " "
        if ($Parts.Count -lt 2) {
            return
        }

        $SrcRepo = Ensure-GitSuffix -RepoUrl $Parts[0]
        $TargetRepo = Ensure-GitSuffix -RepoUrl $Parts[1]

        # Clone repository if not done yet
        Clone-Repo -RepoUrl $SrcRepo

        # Push the repository to target
        Push-NewRemote -SrcRepo $SrcRepo -TargetRepo $TargetRepo
    }
}

# Run main function
Main
