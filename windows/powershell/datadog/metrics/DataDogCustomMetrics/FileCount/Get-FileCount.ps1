<#
    .SYNOPSIS
    Scan a path recursively and get a count of all files within.

    .DESCRIPTION
    Script starts scanning at the -FolderPath input (default: "C:\path\to\dir\to\scount"). For each directory or file found,
    the script checks all patterns in -IgnorePatterns, and if the file/directory matches a pattern, it is ignored/skipped.

    For each file *not* skipped in this manner, a $FileCount variable is incremented, and once the full scan is complete,
    the $FileCount variable is returned.

    This script requires 2 environment variables: $DATADOG_API_KEY and $DATADOG_FILECOUNT_APP_KEY.
    You can set these variables with:
        - $env:DATADOG_API_KEY = "YOUR_API_KEY"
        - $env:DATADOG_FILECOUNT_APP_KEY = "YOUR_APP_KEY"

    If these variables are not set, the script will exit with a non-zero exit code.

    .PARAMETER FolderPath
    The root path to start scanning at.

    .PARAMETER IgnorePatterns
    An array of string values representing file/directory names, or a regex pattern like *.filetype. Any path encountered that
    matches one of these strings will be skipped during the scan.

    .PARAMETER Debug
    Enable Write-Debug messages

    .PARAMETER Verbose
    Enable Write-Verbose and Write-Debug messages

    .EXAMPLE
    Get-FileCount -Debug -FolderPath C:\Some\Path\to\Scan -IgnorePatterns @("*.tmp", "*.bak", "A filename", "a_directory_name")
#>
Param(
    # Define the path to the folder as a parameter
    # so it can be changed by passing -folderPath
    [string]$FolderPath = "C:\path\to\directory\to\count",
    # Array of path/file names to ignore during recursive scans
    $IgnorePatterns = @(
        "DirectoryName1",
        "DirectoryName2",
        "FilePattern*"
    ),
    # If -Debug is passed, debug logging will be enabled
    [switch]$Debug,
    # If -Verbose is passed, verbose logging will be enabled
    [switch]$Verbose,
    ## Your Datadog API key
    [string]$APIKey = "$($env:DATADOG_API_KEY)",
    ## Your Datadog app key
    [string]$AppKey = "$($env:DATADOG_FILECOUNT_APP_KEY)",
    ## Environment string for Datadog POST metric
    [string]$DatadogEnv = "prod"
)

# Enable Write-Information messages
$InformationPreference = "Continue"

#Start Logging
Start-Transcript -OutputDirectory C:\Logs\datadog_metric_upload\FileCount

if ( $Verbose ) {
    # Enable Write-Verbose and Write-Debug messages when -Verbose is present
    $DebugPreference = "Continue"
    $VerbosePreference = "Continue"

    Write-Verbose "[DEBUG] and [VERBOSE] logging enabled"
}
elseif ( $Debug ) {
    # Enable debug logging when -Debug is passed without -Verbose
    $DebugPreference = "Continue"

    Write-Debug "[DEBUG] logging enabled"
}
else {
    # When no -Verbose param is detected, silence Write-Verbose & Write-Debug messages
    $DebugPreference = "SilentlyContinue"
    $VerbosePreference = "SilentlyContinue"
}

function Get-FileCount {
    <#
        .SYNOPSIS
        Scan a directory recursively (-ScanPath <directory>) and count the number of file items within.

        .PARAMETER ScanPath
        The root path to scan.

        .PARAMETER IgnorePatterns
        An array of strings declaring file/directory names and/or patterns to ignore/skip during the scan.

        .EXAMPLE
        Get-FileCount -ScanPath C:\Path\To\Scan -IgnorePatterns @("tmp", ".tmp", ".bak")
    #>
    Param(
        [string]$ScanPath = $global:FolderPath,
        [string[]]$IgnorePatterns
    )

    If ( -Not $ScanPath ) {
        # No value detected for -ScanPath
        Write-Error "Missing path to scan."
        return 0
    }

    If ( -Not ( Test-Path -Path $($ScanPath) ) ) {
        Write-Error "The path '$($ScanPath)' does not exist."
        return 0
    }

    Write-Debug "Scan path: $($ScanPath)"

    If ( -Not $IgnorePatterns ) {
        # No value detected for -IgnorePatterns
        Write-Warning "No -IgnorePatterns detected, all paths will be scanned and all files will be counted."
    }

    # Initialize file count
    $FileCount = 0

    function Test-PathIsIgnored {
        <#
            .SYNOPSIS
            Test if a directory/filename is in a list of ignored files/directories.

            .PARAMETER ItemName
            The name of a file/directory to compare to the list of ignored patterns.
        #>
        Param(
            [string]$ItemName
        )

        ForEach ( $Pattern in $IgnorePatterns ) {
            If ( $ItemName -like $Pattern ) {
                Write-Verbose "Item name '$($ItemName)' matches a pattern in `$IgnorePatterns and will be skipped."
                return $true
            }
        }

        # ItemName does not match a pattern in IgnorePatterns
        return $false
    }

    function Start-RecursiveScan {
        <#
            .SYNOPSIS
            Recursively scan a path for functions, skipping ignored paths & returning an integer count of all
            files found in the recursive scan.

            .PARAMETER CurrentDirectory
            The starting/"root" path for a scan.
        #>
        Param(
            [string]$CurrentDirectory
        )

        # Get all items in the current directory
        Get-ChildItem -Path $CurrentDirectory -Force | ForEach-Object {
            # Skip items that match an ignore pattern
            If (Test-PathIsIgnored -ItemName $_.Name ) {
                Write-Verbose "Ignoring path: $($_.FullName)"
                # Return immediately, skipping the scan of the ignored path
                return
            }

            If ( $_.PSIsContainer ) {
                # Path $_ is a directory, start a new recursive scan
                Start-RecursiveScan -CurrentDirectory $_.FullName
            }
            else {
                # Path $_ is a file, increment the file counter
                $script:FileCount++
            }
        }
    }

    Write-Information "Starting recursive scan of path: $($ScanPath)"

    # Start scanning from the root directory
    Start-RecursiveScan -CurrentDirectory $ScanPath

    # Return the file count after all paths have been scanned
    return $script:FileCount
}

function unixTime() {
    ## Return a Unix timestamp
    Return (Get-Date -date ((get-date).ToUniversalTime()) -UFormat %s) -Replace ("[,\.]\d*", "")
}

function postMetric($url, $metric, $tags) {
    ## Send POST request to DataDog with custom metric

    $currenttime = unixTime
    $host_name = $env:COMPUTERNAME #optional parameter .

    # Construct JSON
    $points = , @($currenttime, $metric.amount)
    $post_obj = [pscustomobject]@{"series" = , @{"metric" = $metric.name;
            "points"                                      = $points;
            "type"                                        = "gauge";
            "host"                                        = $host_name;
            "tags"                                        = $tags
        }
    }
    $post_json = $post_obj | ConvertTo-Json -Depth 5 -Compress

    Write-Debug "POST request body: $($post_json)"
    
    # POST to DD API
    try {
        Write-Output "Posting results to DataDog"

        If ( $Debug ) {
            Write-Debug "POST URL: $($url)"
            Write-Debug "Body $($post_json)"
        }

        $response = Invoke-RestMethod -Method Post -Uri $url -Body $post_json -ContentType "application/json" | ConvertTo-Json -Depth 10

        Write-Debug "Response: $($response)"
    }
    catch {
        Write-Error "Unhandled exception POSTing query results to DataDog. Details: $($_.exception.message)"
        exit(1)
    }
}

function Send-ToDataDog() {
    ## Build POST request & send to DataDog

    Param(
        [String]$app_key = $AppKey,
        [String]$api_key = $APIKey,
        [String]$url_base = "https://us3.datadoghq.com/",
        [String]$url_signature = "api/v1/series",
        [String]$tags = "[env:prod]",
        [String]$FileCount = $null
    )

    Write-Output "POSTing file count to Datadog"

    If ( -Not $FileCount ) {
        Write-Error "Missing a count of files"

        exit(1)
    }

    ## Build the request URL
    $url = $url_base + $url_signature + "?api_key=$($APIKey)" + "&" + "application_key=$($AppKey)"
    ## Set env tag
    $tags = "[env:$($DataDogEnv)]" #optional parameter

    # Select what to send to Datadog. In this example, the number of handles opened by process "mmc" is being sent
    $metric_ns = "fileCount.count" # your desired metric namespace

    Write-Debug "DataDog metric namespace: $($metric_ns)"
    
    ## Create request body
    [System.Collections.Hashtable]$metric = @{"name" = $metric_ns; "amount" = $FileCount }
    If ( $Debug ) {
        Write-Debug "Debug `$metric:"
    
        ForEach ($pair in $metric.GetEnumerator()) {
            Write-Debug "Key: $($pair.Key)`n`tValue: $($pair.Value)"
        }
    }

    ## Send POST request to DataDog
    postMetric($url)($metric)($tags) # pass your metric as a parameter to postMetric()
    Write-Output "[SUCCESS] Uploaded file count metric to DataDog."
}

## Script main execution
Write-Information "Scanning path '$($FolderPath)' to get a count of files within. Path will be scanned recursively. Ignoring [$($IgnorePatterns.Count)] pattern(s) during scan."
$IgnorePatterns | ForEach-Object {
    Write-Verbose "IGNORE pattern: $($_)"
}

try {
    $FileCount = (Get-FileCount -ScanPath $FolderPath -IgnorePatterns $IgnorePatterns)
    Write-Information "Counted [$($FileCount)] file(s) in path: $($FolderPath)."

    Write-Information "Sending results to Datadog"
    try {
        Send-ToDataDog -FileCount $FileCount
    }
    catch {
        Write-Error "Error uploading file count to Datadog. Details: $($_.Exception.Message)"
        Stop-Transcript
        exit 1
    }
    Stop-Transcript
    exit 0
}
catch {
    Write-Error "Error counting files in path '$($FolderPath)'. Details: $($_.Exception.Message)"
    Stop-Transcript
    exit $LASTEXITCODE
}
