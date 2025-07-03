<#
.SYNOPSIS
    Retrieves environment variables for multiple Azure App Services and their slots.

.DESCRIPTION
    This script calls List-AzAppEnvVars.ps1 for each resource specified in the Resources parameter.
    Each resource should be a hashtable with ResourceGroup and AppService properties.

.PARAMETER Resources
    An array of hashtables, each containing ResourceGroup and AppService properties.

.EXAMPLE
    $resources = @(
        @{ ResourceGroup = "EpiAppsProd"; AppService = "EpiAccount-p" },
        @{ ResourceGroup = "EpiAppsProd"; AppService = "EpiManagement-p" },
        @{ ResourceGroup = "EpiAppsStage"; AppService = "EpiAccount-s" }
    )
    .\Get-MultipleAzAppEnvVars.ps1 -Resources $resources

.EXAMPLE
    # Using a more compact syntax
    .\Get-MultipleAzAppEnvVars.ps1 -Resources @(
        @{ ResourceGroup = "RG1"; AppService = "App1" },
        @{ ResourceGroup = "RG2"; AppService = "App2" }
    )
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [hashtable[]]$Resources,
    [Parameter(Mandatory = $false)]
    [switch]$SaveToJson,
    [Parameter(Mandatory = $false)]
    [string]$JsonOutputDirectory = "."
)

function List-AzAppEnvVars {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$AppService,

        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = ".",

        [Parameter(Mandatory = $false)]
        [switch]$SaveToJson
    )

    Write-Host "Processing $AppService ..."

    # Get the list of slots (excluding production)
    $slots = az webapp deployment slot list `
        --name $AppService `
        --resource-group $ResourceGroup `
        --query "[].name" `
        -o tsv

    # Include production slot explicitly
    $allSlots = @("production") + $slots

    # Create a hashtable to store all slot settings
    $envVarsBySlot = @{}

    foreach ($slot in $allSlots) {
        if ($slot -eq "production") {
            $slotName = "production"
        }
        else {
            $slotName = $slot
        }

        Write-Host "  Fetching env vars for slot: $slotName"

        if ($slot -eq "production") {
            $envVarsJson = az webapp config appsettings list `
                --name $AppService `
                --resource-group $ResourceGroup `
                --output json
        }
        else {
            $envVarsJson = az webapp config appsettings list `
                --name $AppService `
                --resource-group $ResourceGroup `
                --slot $slot `
                --output json
        }

        $envVarsBySlot[$slotName] = $envVarsJson | ConvertFrom-Json
    }

    if ( $SaveToJson ) {
        ## Convert the hashtable to JSON and save to file
        if ( -not ( Test-Path -Path $OutputDirectory ) ) {
            # Create the output directory if it doesn't exist
            New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
        }

        $outputFile = Join-Path $OutputDirectory "$AppService-env-vars.json"
        $envVarsBySlot | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $outputFile

        Write-Host "Environment variables saved to $outputFile"
    }

    ## Return JSON results
    $envVarsBySlot
}

Write-Host "Processing $($Resources.Count) resources..." -ForegroundColor Green
Write-Host ("=" * 50)

$successCount = 0
$errorCount = 0
$results = @()

foreach ($resource in $Resources) {
    # Validate required properties
    if (-not $resource.ContainsKey("ResourceGroup") -or -not $resource.ContainsKey("AppService")) {
        Write-Warning "Skipping invalid resource entry - missing ResourceGroup or AppService property"
        $errorCount++
        continue
    }

    $resourceGroup = $resource.ResourceGroup
    $appService = $resource.AppService
    
    Write-Host ""
    Write-Host "Processing: $appService in $resourceGroup" -ForegroundColor Cyan
    Write-Host ("-" * 40)

    try {
        # Call the function with SaveToJson switch
        List-AzAppEnvVars -ResourceGroup $resourceGroup -AppService $appService -OutputDirectory $JsonOutputDirectory -SaveToJson:$SaveToJson
        
        if ($SaveToJson) {
            # Only check for output file if SaveToJson was specified
            $outputFile = "$($JsonOutputDirectory)/$appService-env-vars.json"
            if (Test-Path $outputFile) {
                $results += @{
                    ResourceGroup = $resourceGroup
                    AppService    = $appService
                    OutputFile    = $outputFile
                    Status        = "Success"
                }
                $successCount++
                Write-Host "✓ Successfully processed $appService" -ForegroundColor Green
            }
            else {
                throw "Output file was not created"
            }
        } else {
            # If not saving to JSON, just mark as successful
            $results += @{
                ResourceGroup = $resourceGroup
                AppService    = $appService
                OutputFile    = $null
                Status        = "Success"
            }
            $successCount++
            Write-Host "✓ Successfully processed $appService" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to process $appService in $resourceGroup`: $($_.Exception.Message)"
        $results += @{
            ResourceGroup = $resourceGroup
            AppService    = $appService
            OutputFile    = $null
            Status        = "Failed"
            Error         = $_.Exception.Message
        }
        $errorCount++
    }
}

# Summary
Write-Host ""
Write-Host ("=" * 50)
Write-Host "SUMMARY" -ForegroundColor Yellow
Write-Host ("=" * 50)
Write-Host "Total resources processed: $($Resources.Count)"
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $errorCount" -ForegroundColor Red

if ($results.Count -gt 0) {
    Write-Host ""
    Write-Host "Detailed Results:" -ForegroundColor Yellow
    $results | ForEach-Object {
        $status = if ($_.Status -eq "Success") { "✓" } else { "✗" }
        $color = if ($_.Status -eq "Success") { "Green" } else { "Red" }
        Write-Host "$status $($_.AppService) ($($_.ResourceGroup))" -ForegroundColor $color
        if ($_.OutputFile) {
            Write-Host "  Output: $($_.OutputFile)" -ForegroundColor Gray
        }
        if ($_.Error) {
            Write-Host "  Error: $($_.Error)" -ForegroundColor Red
        }
    }
}
