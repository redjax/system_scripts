param(
    [String]$OutputPath = "C:\tmp\scheduled_tasks",
    [Boolean]$Debug = $false
)

## Add custom tasks to this array to loop over them
$ExportTasks = @(
    [PSCustomObject]@{
        Name       = "Kill Discord";
        Path       = "\CustomTasks";
        OutputFile = "$($OutputPath)\kill discord.xml"
    }
)

function Export-Tasks {
    param(
        [Array]$tasks = $ExportTasks
    )

    ForEach ( $Task in $tasks ) {
        If ( $Debug ) {
            Write-Host "Task Name: $($Task.Name)"
            Write-Host "Task Path: $($Task.Path)"
            Write-Host "Output File: $($Task.OutputFile)"
        }

        If ( -Not ( Test-Path "$($Task.OutputFile)" -PathType Leaf ) ) {
            Write-Host "Exporting task [$($Task.Path)\$($Task.Name)] to file [$($Task.OutputFile)]"
        
        
            try {
                Export-ScheduledTask -TaskPath "$($Task.Path)" -TaskName "$($Task.Name)" | Set-Content -Path "$($Task.OutputFile)"
            }
            catch {
                Write-Error "Error writing task to file $($Task.OutputFile). Exception details: $($_.Exception.Message)"
            }

        }
        else {
            Write-Host "Task export for [$($Task.Name)] already exists at path [$($Task.OutputFile)]"
        }
    }
}

If ( -Not ( Test-Path "$($OutputPath)") ) {
    Write-Host "Output path [$($OutputPath)] does not exist. Creating"

    try {
        New-Item -Path $OutputPath -ItemType Directory -Force
    }
    catch {
        Write-Error "Unhandled exception creating path [$($OutputPath)]. Details: $($_.Exception.Message)"
    }

}

Export-Tasks
