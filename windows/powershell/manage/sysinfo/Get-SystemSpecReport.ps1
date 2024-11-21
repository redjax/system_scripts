
<#
    .SYNOPSIS
    Get system information and save to file.
    
    .DESCRIPTION
    Get system information and save to file.
    
    .PARAMETER Debug
    Enable Debug mode.

    .PARAMETER Save
    Save report to file.

    .PARAMETER OutputDirectory
    Specify the output directory for the report file.

    .PARAMETER OutputFilename
    Specify the filename for the report file.

    .PARAMETER OutputFormat
    Specify the format for the report file (json, xml, txt).

    .EXAMPLE
    Get-SystemSpecReport -Save -OutputDirectory "C:\Temp" -OutputFilename "SystemReport" -OutputFormat "xml"
#>
Param(
    [switch]$Debug,
    [switch]$Save,
    [switch]$Help,
    [string]$OutputDirectory = "${env:USERPROFILE}\SystemReport",
    [string]$OutputFilename = "SystemReport",
    [string]$OutputFormat = "json"
)

If ( $Help ) {
    Write-Host "`n[[ Get-SystemSpecReport Help ]]" -ForegroundColor Green
    Write-Host ("-" * 31)
    Write-Host ""

    Write-Host "Compile a report of system information, including OS & Powershell environment," `
        "CPU, GPU, GRAM, disks, and motherboard. Optionally export to a file with -Save.`n" -ForegroundColor Magenta
    
    Write-Host "[Params]`n" -ForegroundColor cyan

    Write-Host "-Save" -ForegroundColor cyan -NoNewline; Write-Host ": Save report to file."
    Write-Host "-Debug" -ForegroundColor cyan -NoNewline; Write-Host ": Enable debug mode."
    Write-Host "-OutputDirectory" -ForegroundColor cyan -NoNewline; Write-Host ": Specify the output directory for the report file."
    Write-Host "-OutputFilename" -ForegroundColor cyan -NoNewline; Write-Host ": Specify the filename for the report file."
    Write-Host "-OutputFormat" -ForegroundColor cyan -NoNewline; Write-Host ": Specify the format for the report file (json, xml, txt)."
    Write-Host ""

    ## Format shell code example using -NoNewline;
    Write-Host "Example" -ForegroundColor Magenta -NoNewline; Write-Host ": Save report to C:\Temp\SystemReport.xml"
    Write-Host "    $> " -NoNewline;
    Write-Host ".\Get-SystemSpecReport.ps1 " -ForegroundColor Yellow -NoNewline;
    Write-Host "-Save " -ForegroundColor cyan -NoNewline;
    Write-Host "-OutputDirectory " -ForegroundColor cyan -NoNewline;
    Write-Host "C:\Temp " -NoNewline;
    Write-Host "-OutputFilename " -ForegroundColor cyan -NoNewline;
    Write-Host "SystemReport " -NoNewline;
    Write-Host "-OutputFormat " -ForegroundColor cyan -NoNewline; 
    Write-Host  "xml"

    Write-Host ""

    exit 0
}

if ( $Debug ) {
    $DebugPreference = "Continue"
}

function Format-ByteSize {
    <#
    .SYNOPSIS
    Format a size in bytes to a human-readable form (i.e. 1000000 bytes = 1MB)
    
    # .DESCRIPTION
    
    .PARAMETER SizeInBytes
    Parameter An integer representing a size in bytes to be converted to human-readable form.
    
    .EXAMPLE
    Format-ByteSize -SizeInBytes 1000000
    
    # .NOTES
    #>
    param (
        [int64]$SizeInBytes
    )

    Write-Debug "Converting $($SizeInBytes) bytes to human-readable form."

    if ($SizeInBytes -lt 1KB) {
        return "{ 0:N2 } B" -f $SizeInBytes
    }
    elseif ($SizeInBytes -lt 1MB) {
        return "{ 0:N2 } KB" -f ($SizeInBytes / 1KB)
    }
    elseif ($SizeInBytes -lt 1GB) {
        return "{ 0:N2 } MB" -f ($SizeInBytes / 1MB)
    }
    elseif ($SizeInBytes -lt 1TB) {
        return "{ 0:N2 } GB" -f ($SizeInBytes / 1GB)
    }
    elseif ($SizeInBytes -lt 1PB) {
        return "{ 0:N2 } TB" -f ($SizeInBytes / 1TB)
    }
    else {
        return "{ 0:N2 } PB" -f ($SizeInBytes / 1PB)
    }
}

function Get-PowerShellEnvironment {
    <#
        .SYNOPSIS
        Get information about the current PowerShell environment.

        .DESCRIPTION
        Get information about the current PowerShell environment, such as version, edition, and host.

        .OUTPUTS
        A custom object containing the PowerShell version, edition, and host.

        .EXAMPLE
        $environmentDetails = Get-PowerShellEnvironment
    #>
    $shellVersion = $PSVersionTable.PSVersion
    $shellEdition = $PSVersionTable.PSEdition
    $shellHost = $host.Name
    $shellHostVersion = $host.Version
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem | Select-Object Caption, OSArchitecture

    # Creating a custom object to store the information
    $environmentDetails = [pscustomobject]@{
        PowerShellVersion = "$($shellVersion.Major).$($shellVersion.Minor).$($shellVersion.Build)"
        PowerShellEdition = $shellEdition
        PowerShellHost    = $shellHost
        HostVersion       = $shellHostVersion
        OSName            = $osInfo.Caption
        OSArchitecture    = $osInfo.OSArchitecture
    }

    return $environmentDetails
}

function Get-SystemSpecs {
    <#
        .SYNOPSIS
        Get system information report.
        
        .DESCRIPTION
        Compile data about system's hardware & OS, return a PSCustomObject that can be saved as XML, JSON, or TXT.

        .EXAMPLE
        Get-SystemSpecs
    #>

    Write-Host "Gathering environment information..." -ForegroundColor Cyan
    try {
        # $osInfo = Get-ComputerInfo | Select-Object WindowsVersion, WindowsBuildLabEx, CsName, CsSystemManufacturer, CsSystemProductName
        $envDetails = (Get-PowerShellEnvironment)
    }
    catch {
        Write-Error "Error gathering environment information: $($_.Exception.message)"
    }

    Write-Host "Gathering motherboard information..." -ForegroundColor Cyan
    try {
        $motherboardInfo = Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product, SerialNumber
    }
    catch {
        Write-Error "Error gathering motherboard information: $($_.Exception.message)"
    }

    Write-Host "Gathering CPU information..." -ForegroundColor Cyan
    try {
        # $cpuInfo = Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, Manufacturer
        $cpuInfo = Get-CimInstance Win32_Processor | Select-Object @{Name = 'Name'; Expression = { $_.Name.Trim() } }, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, Manufacturer
    }
    catch {
        Write-Error "Error gathering CPU information: $($_.Exception.message)"
    }

    Write-Host "Gathering RAM information..." -ForegroundColor Cyan
    try {
        $ramInfo = Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
            [pscustomobject]@{
                Capacity     = Format-ByteSize $_.Capacity
                Manufacturer = $_.Manufacturer
                SpeedMHz     = $_.Speed
            }
        }
    }
    catch {
        Write-Error "Error gathering RAM information: $($_.Exception.message)"
    }

    Write-Host "Gathering GPU information..." -ForegroundColor Cyan
    try {
        $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM, DriverVersion, VideoProcessor
    }
    catch {
        Write-Error "Error gathering GPU information: $($_.Exception.message)"
    }

    Write-Host "Gathering disk information..." -ForegroundColor Cyan
    try {
        $diskInfo = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
            [pscustomobject]@{
                Drive      = $_.DeviceID
                FileSystem = $_.FileSystem
                FreeSpace  = Format-ByteSize $_.FreeSpace
                TotalSpace = Format-ByteSize $_.Size
                VolumeName = $_.VolumeName
            }
        }
    }
    catch {
        Write-Error "Error gathering disk information: $($_.Exception.message)"
    }

    Write-Host "Generating report..." -ForegroundColor Magenta
    $report = [PSCustomObject]@{
        EnvironmentInfo  = $envDetails
        Motherboard_Info = $motherboardInfo
        CPU_Info         = $cpuInfo
        RAM_Info         = $ramInfo
        GPU_Info         = $gpuInfo
        Disk_Info        = $diskInfo
    }

    return $report
}

function Save-SysInfoReport {
    Param(
        $Report,
        $OutputDirectory = $OutputDirectory,
        $OutputFilename = $OutputFilename,
        $OutputFormat = $OutputFormat
    )

    If ( -Not $Report ) {
        Write-Error "`$Report is missing or empty."
        exit 1
    }

    Write-Host "Saving report to directory '$($OutputDirectory)'" -ForegroundColor Magenta

    Write-Debug "Output Directory: $($OutputDirectory)"
    Write-Debug "Output Filename: $($OutputFilename)"
    Write-Debug "Output Format: $($OutputFormat)"

    $OutputFile = "$($OutputDirectory)\$($OutputFilename)"
    Write-Debug "Output File (without extension): $($OutputFile)"

    if (-not (Test-Path -Path $OutputDirectory)) {
        try {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
            Write-Host "Directory '$OutputDirectory' was created." -ForegroundColor Green
        }
        catch {
            Write-Error "-Save parameter found, but could not create non-existent output directory '$($OutputDirectory)'. Details: $($_.Exception.Message)"
            exit 1
        }
    }

    ## Save report
    switch ($OutputFormat) {
        "json" {
            try {
                $report | ConvertTo-Json -Depth 3 | Set-Content "$($OutputFile).json"
                Write-Host "Exported system report to $($OutputFile).json" -ForegroundColor Green
            }
            catch {
                Write-Error "Error exporting system report to JSON: $($_.Exception.Message)"
            }
        }
        "xml" {
            try {
                $report | Export-Clixml "$($OutputFile).xml"
                Write-Host "Exported system report to $($OutputFile).xml" -ForegroundColor Green
            }
            catch {
                Write-Error "Error exporting system report to XML: $($_.Exception.Message)"
            }
        }
        "txt" {
            try {
                $report | Out-File "$($OutputFile).txt"
                Write-Host "Exported system report to $($OutputFile).txt" -ForegroundColor Green
            }
            catch {
                Write-Error "Error exporting system report to TXT: $($_.Exception.Message)"
            }
        }
        default {
            Write-Host "Error: Invalid output format specified: '$($OutputFormat)'. Must be 'json', 'xml', or 'txt'." -ForegroundColor Red
        }
    }
}

## Build system info report
$report = (Get-SystemSpecs)

Write-Host "`n--== [[ System Info Report ]]==--" -ForegroundColor Green
Write-Host ("-" * 34)

$report | Format-List

## Save report if -Save param detected
If ( $Save ) {
    Save-SysInfoReport -Report $report -OutputDirectory $OutputDirectory -OutputFilename $OutputFilename -OutputFormat $OutputFormat
}
