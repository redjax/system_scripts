Param (
    [Parameter(Mandatory = $false, HelpMessage = "Path to a definition .json file for the script to read from.")]
    [string]$DefinitionFile
)

$DirSeparator = [System.IO.Path]::DirectorySeparatorChar

$ExampleDefinitionsObject = @(
    @{
        remote_host = "example_hostname";
        definitions = @(
            @{
                direction = "[push/pull]";
                type      = "[file/directory]";
                remote    = "/path/to/remote";
                local     = "/path/on/local/machine"
            }
        )
    }
)

Write-Verbose "Directory separator: $($DirSeparator)"
Write-Verbose "Definitions file: $($DefinitionFile)"

if ( -not ( Get-Command "scp" -ErrorAction SilentlyContinue ) ) {
    Write-Error "scp is not installed. Please install scp and try again."
    exit 1
}

if ( -Not ( $DefinitionFile ) ) {
    $DefinitionFile = "$($PSScriptRoot)$($DirSeparator)backup_definitions.json"
    Write-Information "No -DefinitionFile passed, using default definitions file: $($DefinitionFile)"
}

if ( -Not ( Test-Path -Path $DefinitionFile ) ) {
    Write-Error "Could not find definitions file: $($DefinitionFile)"
    
    $ExampleDefinitionsJson = $ExampleDefinitionsObject | ConvertTo-Json -Depth 10 -AsArray
    $ExampleDefinitionsFile = "$PSScriptRoot$DirSeparator" + "example.backup_definitions.json"
    $ExampleDefinitionsJson | Set-Content -Path $ExampleDefinitionsFile
    
    Write-Output "Example definitions file created: $ExampleDefinitionsFile"
    Write-Output "Please modify this file with your backup definitions and rerun the script."
    Write-Output "When you are finished, remove the 'example.' from the beginning of the filename, so you are left with 'backup_definitions.json'."

    exit 1
}

Write-Information "Load backup definitions from file: $($DefinitionFile)"
$BackupDefinitions = Get-Content "$($DefinitionFile)" | ConvertFrom-Json

foreach ( $entry in $BackupDefinitions ) {
    Write-Verbose "Entry: $($entry)"
    $RemoteHost = $entry.remote_host
    Write-Debug "Remote host: $($RemoteHost)"

    foreach ( $Definition in $entry.definitions ) {
        Write-Debug "[$($RemoteHost)] Backup definition: $($Definition)"
        $Direction = $Definition.direction
        $SynchType = $Definition.type
        $RemotePath = $Definition.remote
        $LocalPath = $Definition.local

        if ( $Direction -eq "push" ) {
            Write-Debug "$SynchType Operation: PUSH $($LocalPath) TO $($RemoteHost):$($RemotePath)"
            if ( $SynchType -eq "directory" ) {
                $SCPCommand = "scp -r `"$LocalPath`" `"$RemoteHost`:$RemotePath`""
            }
            elseif ( $SynchType -eq "file" ) {
                $SCPCommand = "scp `"$LocalPath`" `"$RemoteHost`:$RemotePath`""
            }
            else {
                Write-Warning "Unknown synch type: $($SynchType). Expected 'directory' or 'file'."
                continue
            }
        }
        elseif ( $Direction -eq "pull" ) {
            Write-Debug "Operation: PULL $($RemoteHost):$($RemotePath) TO $($LocalPath)"
            if ( $SynchType -eq "directory" ) {
                $SCPCommand = "scp -r `"$RemoteHost`:$RemotePath`" `"$LocalPath`""
            }
            elseif ( $SynchType -eq "file" ) {
                $SCPCommand = "scp `"$RemoteHost`:$RemotePath`" `"$LocalPath`""
            }
            else {
                Write-Warning "Unknown synch type: $($SynchType). Expected 'directory' or 'file'."
                continue
            }
        }
        else {
            Write-Warning "Unknown direction '$($Direction)' in definition. Skipping."
            continue
        }

        Write-Output "[SCP Command Preview] (direction: $($Direction)) `$> $($SCPCommand)"
        try {
            Invoke-Expression $SCPCommand
        }
        catch {
            Write-Error "Error executing SCP command. Details: $($_.Exception.Message)"
            exit 1
        }
    }
}
