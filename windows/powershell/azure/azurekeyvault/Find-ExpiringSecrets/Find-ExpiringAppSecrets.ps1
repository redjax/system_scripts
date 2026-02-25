<#
.SYNOPSIS
    Finds Azure AD App Registration client secrets expiring soon.

.DESCRIPTION
    This script searches Azure AD App Registrations for client secrets (passwordCredentials) that are 
    expiring within specified thresholds. It categorizes secrets by expiration urgency and can send notifications.

.PARAMETER AppNameFilter
    Optional filter for application display names (supports wildcards). If not specified, checks all apps.

.PARAMETER AppRoleFilter
    Optional filter for apps containing specific appRole values (e.g., 'ApiAppRole').

.PARAMETER RequirePasswordCredentials
    Only check apps that have password credentials. Default is $true.

.PARAMETER DaysThreshold
    Array of day thresholds for expiration warnings. Default is @(10, 30, 60).

.PARAMETER OutputFormat
    Output format: Table, Json, or Csv. Default is Table.

.PARAMETER ExportPath
    Optional path to export results. Format determined by OutputFormat parameter.

.PARAMETER TeamsWebhookUrl
    Optional Teams webhook URL to send notifications.

.PARAMETER EnvironmentSuffixMapping
    Hashtable to map app name suffixes to environment names (e.g., @{'-p'='prod'; '-np'='rc'; '-dev'='dev'}).

.EXAMPLE
    .\Find-ExpiringAppSecrets.ps1

.EXAMPLE
    .\Find-ExpiringAppSecrets.ps1 -AppNameFilter "Epi*" -DaysThreshold @(7,14,30)

.EXAMPLE
    .\Find-ExpiringAppSecrets.ps1 -AppRoleFilter "ApiAppRole" -TeamsWebhookUrl "https://..."

.EXAMPLE
    .\Find-ExpiringAppSecrets.ps1 -AppNameFilter "MyApp*" -OutputFormat Json -ExportPath "expiring-secrets.json"

.NOTES
    Author: System Scripts
    Requires: Azure CLI (az) authenticated via 'az login' with permissions to read App Registrations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AppNameFilter,

    [Parameter(Mandatory = $false)]
    [string]$AppRoleFilter,

    [Parameter(Mandatory = $false)]
    [bool]$RequirePasswordCredentials = $true,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [int[]]$DaysThreshold = @(10, 30, 60),

    [Parameter(Mandatory = $false)]
    [ValidateSet('Table', 'Json', 'Csv')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory = $false)]
    [string]$ExportPath,

    [Parameter(Mandatory = $false)]
    [string]$TeamsWebhookUrl,

    [Parameter(Mandatory = $false)]
    [hashtable]$EnvironmentSuffixMapping = @{
        '-p' = 'prod'
        '-np' = 'rc'
        '-dev' = 'dev'
    }
)

# Check if Azure CLI is available
try {
    $azVersion = az version | ConvertFrom-Json
    Write-Verbose "Using Azure CLI version: $($azVersion.'azure-cli')"
}
catch {
    Write-Error "Azure CLI is not installed or not in PATH. Install from: https://aka.ms/InstallAzureCliWindows"
    exit 1
}

function Get-EnvironmentFromAppName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$SuffixMapping
    )

    foreach ($suffix in $SuffixMapping.Keys) {
        if ($AppName.EndsWith($suffix)) {
            return $SuffixMapping[$suffix]
        }
    }
    
    return "unknown"
}

function Get-ExpiringAppSecrets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$NameFilter,
        
        [Parameter(Mandatory = $false)]
        [string]$RoleFilter,
        
        [Parameter(Mandatory = $true)]
        [bool]$RequirePasswords,
        
        [Parameter(Mandatory = $true)]
        [int[]]$Thresholds,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$EnvMapping
    )

    Write-Host "Querying Azure AD App Registrations..." -ForegroundColor Cyan
    
    # Build the query filter
    $queryParts = @()
    
    if ($RequirePasswords) {
        $queryParts += "length(passwordCredentials) > ``0``"
    }
    
    if ($RoleFilter) {
        $queryParts += "contains(appRoles[].value, '$RoleFilter')"
    }
    
    $queryFilter = if ($queryParts.Count -gt 0) {
        "[?" + ($queryParts -join " && ") + "]"
    } else {
        "[]"
    }
    
    # Query for apps
    Write-Verbose "Query filter: $queryFilter"
    $appsJson = az ad app list --all --query "$queryFilter.{displayName:displayName, appId:appId, id:id, passwordCredentials:passwordCredentials}" --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to query App Registrations: $appsJson"
        return @()
    }
    
    $apps = $appsJson | ConvertFrom-Json
    Write-Host "Found $($apps.Count) app(s) with password credentials" -ForegroundColor Green
    
    # Apply name filter if specified
    if ($NameFilter) {
        $apps = $apps | Where-Object { $_.displayName -like $NameFilter }
        Write-Host "After name filter '$NameFilter': $($apps.Count) app(s)" -ForegroundColor Yellow
    }
    
    $expiringSecrets = @()
    $now = Get-Date
    
    foreach ($app in $apps) {
        if (-not $app.passwordCredentials -or $app.passwordCredentials.Count -eq 0) {
            continue
        }
        
        $environment = Get-EnvironmentFromAppName -AppName $app.displayName -SuffixMapping $EnvMapping
        
        foreach ($cred in $app.passwordCredentials) {
            if (-not $cred.endDateTime) {
                Write-Verbose "Secret for '$($app.displayName)' has no expiration date"
                continue
            }
            
            # Parse the expiration date
            try {
                $expirationDate = [DateTime]::Parse($cred.endDateTime)
            }
            catch {
                Write-Warning "Could not parse expiration date for app '$($app.displayName)': $($cred.endDateTime)"
                continue
            }
            
            $daysUntilExpiration = [Math]::Round(($expirationDate - $now).TotalDays, 0)
            
            # Determine urgency level based on thresholds
            $urgencyLevel = $null
            $maxThreshold = ($Thresholds | Measure-Object -Maximum).Maximum
            
            if ($daysUntilExpiration -le $maxThreshold) {
                # Find the appropriate threshold bucket
                foreach ($threshold in ($Thresholds | Sort-Object)) {
                    if ($daysUntilExpiration -le $threshold) {
                        $urgencyLevel = $threshold
                        break
                    }
                }

                $startDate = if ($cred.startDateTime) {
                    try { [DateTime]::Parse($cred.startDateTime).ToString("yyyy-MM-dd HH:mm:ss") }
                    catch { $cred.startDateTime }
                } else { "N/A" }

                $secretInfo = [PSCustomObject]@{
                    AppDisplayName    = $app.displayName
                    Environment       = $environment
                    AppId             = $app.appId
                    KeyId             = $cred.keyId
                    DisplayName       = $cred.displayName
                    StartDate         = $startDate
                    ExpirationDate    = $expirationDate.ToString("yyyy-MM-dd HH:mm:ss")
                    DaysUntilExpiry   = $daysUntilExpiration
                    UrgencyThreshold  = $urgencyLevel
                    PortalUrl         = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$($app.appId)"
                    Status            = if ($daysUntilExpiration -lt 0) { "EXPIRED" } 
                                       elseif ($daysUntilExpiration -le $Thresholds[0]) { "CRITICAL" }
                                       elseif ($daysUntilExpiration -le $Thresholds[1]) { "WARNING" }
                                       else { "INFO" }
                }
                
                $expiringSecrets += $secretInfo
                
                Write-Verbose "Found expiring secret: $($app.displayName) - $daysUntilExpiration days remaining"
            }
        }
    }
    
    return $expiringSecrets
}

function Send-TeamsNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WebhookUrl,
        
        [Parameter(Mandatory = $true)]
        [object[]]$Secrets,
        
        [Parameter(Mandatory = $true)]
        [int[]]$Thresholds
    )

    # Group secrets by urgency
    $groupedSecrets = $Secrets | Group-Object -Property UrgencyThreshold | Sort-Object Name
    
    $messageText = "**Azure AD App Registration Secrets Expiration Report**`n`n"
    
    foreach ($group in $groupedSecrets) {
        $threshold = $group.Name
        $count = $group.Count
        $messageText += "**Secrets expiring in $threshold days or less: ($count)**`n"
        
        foreach ($secret in ($group.Group | Sort-Object DaysUntilExpiry)) {
            $envLabel = if ($secret.Environment -ne "unknown") { " [$($secret.Environment)]" } else { "" }
            $messageText += "- [$($secret.AppDisplayName)$envLabel]($($secret.PortalUrl)) - $($secret.DaysUntilExpiry) days remaining`n"
        }
        $messageText += "`n"
    }
    
    # Teams message card format
    $body = @{
        text = $messageText
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $body -ContentType "application/json"
        Write-Verbose "Teams notification sent successfully"
        return $true
    }
    catch {
        Write-Error "Failed to send Teams notification: $_"
        return $false
    }
}

# Main script execution
Write-Host "Starting Azure AD App Registration secret expiration check" -ForegroundColor Cyan

# Check Azure CLI authentication
try {
    $accountJson = az account show 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Not authenticated to Azure. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    
    $account = $accountJson | ConvertFrom-Json
    Write-Verbose "Connected to Azure as: $($account.user.name)"
    Write-Verbose "Tenant: $($account.tenantId)"
}
catch {
    Write-Error "Failed to get Azure account context: $_"
    exit 1
}

# Sort thresholds for proper categorization
$DaysThreshold = $DaysThreshold | Sort-Object

# Display search criteria
Write-Host "`nSearch criteria:" -ForegroundColor Cyan
if ($AppNameFilter) {
    Write-Host "  - App name filter: $AppNameFilter" -ForegroundColor Yellow
}
if ($AppRoleFilter) {
    Write-Host "  - App role filter: $AppRoleFilter" -ForegroundColor Yellow
}
Write-Host "  - Expiration thresholds: $($DaysThreshold -join ', ') days" -ForegroundColor Yellow
Write-Host ""

# Get expiring secrets
$allExpiringSecrets = Get-ExpiringAppSecrets `
    -NameFilter $AppNameFilter `
    -RoleFilter $AppRoleFilter `
    -RequirePasswords $RequirePasswordCredentials `
    -Thresholds $DaysThreshold `
    -EnvMapping $EnvironmentSuffixMapping

# Display results
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total secrets expiring within $($DaysThreshold[-1]) days: $($allExpiringSecrets.Count)"

if ($allExpiringSecrets.Count -gt 0) {
    # Group by urgency for summary
    $criticalCount = @($allExpiringSecrets | Where-Object { $_.Status -eq "CRITICAL" -or $_.Status -eq "EXPIRED" }).Count
    $warningCount = @($allExpiringSecrets | Where-Object { $_.Status -eq "WARNING" }).Count
    $infoCount = @($allExpiringSecrets | Where-Object { $_.Status -eq "INFO" }).Count
    
    Write-Host "  - Critical/Expired (≤$($DaysThreshold[0]) days): $criticalCount" -ForegroundColor Red
    if ($DaysThreshold.Count -gt 1) {
        Write-Host "  - Warning (≤$($DaysThreshold[1]) days): $warningCount" -ForegroundColor Yellow
    }
    if ($DaysThreshold.Count -gt 2) {
        Write-Host "  - Info (≤$($DaysThreshold[2]) days): $infoCount" -ForegroundColor White
    }
    
    Write-Host "`n=== Expiring Secrets ===" -ForegroundColor Cyan
    
    # Sort by days until expiry (most urgent first)
    $sortedSecrets = $allExpiringSecrets | Sort-Object DaysUntilExpiry
    
    # Output based on format
    switch ($OutputFormat) {
        'Table' {
            # Use Out-String with a wide width to prevent truncation, then output
            $sortedSecrets | Format-Table -Property @{
                Label = 'Application'
                Expression = { $_.AppDisplayName }
            }, @{
                Label = 'Env'
                Expression = { $_.Environment }
            }, @{
                Label = 'Days'
                Expression = { $_.DaysUntilExpiry }
                Align = 'Right'
            }, @{
                Label = 'Expiration Date'
                Expression = { $_.ExpirationDate }
            }, @{
                Label = 'Status'
                Expression = { $_.Status }
            } -AutoSize | Out-String -Width 4096 | Out-Host
        }
        'Json' {
            $sortedSecrets | ConvertTo-Json -Depth 10
        }
        'Csv' {
            $sortedSecrets | ConvertTo-Csv -NoTypeInformation
        }
    }
    
    # Export if path specified
    if ($ExportPath) {
        try {
            $exportDir = Split-Path -Path $ExportPath -Parent
            if ($exportDir -and -not (Test-Path $exportDir)) {
                New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
            }
            
            switch ($OutputFormat) {
                'Json' {
                    $sortedSecrets | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
                }
                'Csv' {
                    $sortedSecrets | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
                }
                Default {
                    $sortedSecrets | Out-File -FilePath $ExportPath -Encoding UTF8
                }
            }
            Write-Host "`nResults exported to: $ExportPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to export results: $_"
        }
    }
    
    # Send Teams notification if webhook provided
    if ($TeamsWebhookUrl) {
        Write-Host "`nSending Teams notification" -ForegroundColor Cyan
        $notificationSent = Send-TeamsNotification -WebhookUrl $TeamsWebhookUrl -Secrets $sortedSecrets -Thresholds $DaysThreshold
        if ($notificationSent) {
            Write-Host "Teams notification sent successfully" -ForegroundColor Green
        }
    }
    
    # Exit with error code if critical secrets found
    if ($criticalCount -gt 0) {
        Write-Host "`nWARNING: Found $criticalCount critical/expired secret(s)!" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "No secrets found expiring within $($DaysThreshold[-1]) days." -ForegroundColor Green
}

Write-Host "`nScript completed successfully." -ForegroundColor Green
