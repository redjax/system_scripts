<#
    Add Pyenv bin & shims dir to Windows user's PATH environment variable.
#>

param(
    [Switch]$Debug,
    [Switch]$UserEnv,
    [Switch]$MachineEnv,
    [String]$VarKey = "PATH"
)

$PyenvBinPath = "$env:USERPROFILE\.pyenv\pyenv-win\bin"
$PyenvShimPath = "$env:USERPROFILE\.pyenv\pyenv-win\shims"

If (-Not $UserEnv -and -Not $MachineEnv) {
    Write-Warning "Missing ENV var type. Please re-run the script, passing either -UserEnv or -MachineEnv"
    exit 1
}

If ($UserEnv -and $MachineEnv) {
    Write-Warning "You must pass only 1 type of env variable, -UserEnv or -MachineEnv"
    exit 1
}

If ($UserEnv) {
    $VarType = "User"
}
ElseIf ($MachineEnv) {
    $VarType = "Machine"
}

If ( $Debug ) {
    Write-Host "VarType: $($VarType)" -ForegroundColor Green
}

function Get-PyenvInstall {
    ## Download & install Pyenv

    try {
        Write-Host "Downloading & installing Pyenv install script" -Foreground Blue

        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"; &"./install-pyenv-win.ps1"
    }
    catch {
        Write-Warning "Unhandled exception downloading & installing Pyenv. Details: $($_.Exception.Message)"
    }
}

function Set-UserEnvVar {
    param(
        $VarKey = $null,
        $VarType = $null,
        $VarValue = $null
    )

    if (-not $VarKey) {
        Write-Warning "Missing `$VarKey value"
    }

    if (-not $VarType) {
        Write-Warning "Missing `$VarType value"
    }

    if (-not $VarValue) {
        Write-Warning "Missing `$VarKey value"
    }

    If ( $Debug ) {
        Write-Host "Variable Key: $($VarKey)" -ForegroundColor Green
        Write-Host "Variable Type: $($VarType)" -ForegroundColor Green
        Write-Host "Variable Value: $($VarValue)" -ForegroundColor Green
    }

    ## Get existing PATH variable
    $existingPath = [Environment]::GetEnvironmentVariable($VarKey, $VarType)

    ## Split paths
    $pathsToAdd = @($VarValue -split ";")
    ## Set variable to new value only if it does not exist
    $newPaths = $existingPath -split ";" | Where-Object { $pathsToAdd -notcontains $_ }
    ## Add new $VarValue to newPaths
    $newPaths += $VarValue
    ## Join paths with ;
    $newPath = $newPaths -join ";"

    try {
        [Environment]::SetEnvironmentVariable($VarKey, $newPath, $VarType)

        if ($Debug) {
            Write-Host "Success: Set value of [$($VarType):$($VarKey)]" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Warning "Unhandled exception setting ENV var [$($VarType):$($VarKey)] to value [$newPath]. Details: $($_.Exception.Message)"
        exit 1
    }
}

Get-PyenvInstall

Write-Host "Appending variables to User PATH"

If ( $Debug ) {
    Write-Host "Appending value $($PyenvBinPath) to [$($VarType):$($VarKey)]" -ForegroundColor Green
}

Set-UserEnvVar -VarType $VarType -VarKey $VarKey -VarValue "$PyenvBinPath"

If ( $Debug ) {
    Write-Host "Appending value $($PyenvBinPath) to [$($VarType):$($VarKey)]" -ForegroundColor Green
}
Set-UserEnvVar -VarType $VarType -VarKey $VarKey -VarValue "$PyenvShimPath"