<#
.SYNOPSIS
    Rotate the client secret of an Azure AD app registration and update it in an Azure Key Vault.

.DESCRIPTION
    This script resets the client secret of a specified Azure AD app registration and updates the corresponding secret
    in an Azure Key Vault. It supports dry run mode and confirmation prompts to ensure safe operations.

.PARAMETER AppRegistrationName
    The display name of the Azure AD app registration whose secret is to be rotated.

.PARAMETER Vault
    The name of the Azure Key Vault where the secret is stored.

.PARAMETER SecretName
    The name of the secret in the Key Vault to be updated.

.PARAMETER DryRun
    If specified, the script will simulate the operations without making any changes.

.PARAMETER Force
    If specified, the script will skip confirmation prompts and proceed with the operations.

.EXAMPLE
    .\Rotate-AppRegistrationSecret.ps1 -AppRegistrationName "MyApp" -Vault "MyKeyVault" -SecretName "MyAppSecret"
    Rotates the secret for the app registration "MyApp" and updates the secret in the provided vault.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, HelpMessage = "The display name of the Azure AD app registration")]
    [string]$AppRegistrationName,    
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Key Vault")]
    [string]$Vault,    
    [Parameter(Mandatory = $true, HelpMessage = "The name of the secret in the Key Vault")]
    [string]$SecretName,    
    [Parameter(Mandatory = $false, HelpMessage = "Dry run mode - shows what would happen without making changes")]
    [switch]$DryRun,    
    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
)

function Test-AzureCli {
    if ( -not ( Get-Command az -ErrorAction SilentlyContinue ) ) {
        Write-Error "Azure CLI is not installed or not found in the system PATH."
        
        return $false
    }

    return $true
}

function Get-AppRegistrationId {
    param(
        [string]$DisplayName
    )
    
    Write-Host "`nLooking up app registration: $DisplayName" -ForegroundColor Cyan
    
    ## Look up app registration
    try {
        ## List all apps & filter by display name
        $appList = az ad app list --display-name "$DisplayName" | ConvertFrom-Json
        $app = $appList | Where-Object { $_.displayName -eq "$DisplayName" }
        
        if ( -not $app ) {
            Write-Error "No app registration found with display name: $DisplayName"
            
            return $null
        }
        
        if ( $app.Count -gt 1 ) {
            Write-Error "Multiple app registrations found with display name: $DisplayName"
            Write-Warning "Found the following apps:"

            $app | ForEach-Object { Write-Host "  - $($_.displayName) (ID: $($_.appId))" -ForegroundColor Yellow }

            return $null
        }
        
        Write-Host "Found app registration: $($app.displayName) (ID: $($app.appId))" -ForegroundColor Green
        
        return $app.appId
    }
    catch {
        Write-Error "Failed to retrieve app registration: $($_.Exception.Message)"
        
        return $null
    }
}

function Reset-AppRegistrationSecret {
    param(
        [string]$AppId,
        [bool]$IsDryRun
    )
    
    Write-Host "`nResetting secret for app ID: $AppId" -ForegroundColor Cyan
    
    if ( $IsDryRun ) {
        Write-Host "[DRY RUN] Would reset secret for app ID: $AppId" -ForegroundColor Yellow
        
        return "DRY_RUN_SECRET"
    }
    
    ## Reset the app registration secret and capture the new secret
    try {
        $result = az ad app credential reset --id $AppId | ConvertFrom-Json
        $newSecret = $result.password
        
        if ( -not $newSecret ) {
            Write-Error "Failed to generate new secret - no password returned"
            
            return $null
        }
        
        Write-Host "Successfully generated new secret" -ForegroundColor Green
        
        return $newSecret
    }
    catch {
        Write-Error "Failed to reset app registration secret: $($_.Exception.Message)"
        
        return $null
    }
}

function Test-KeyVaultSecret {
    param(
        [string]$VaultName,
        [string]$SecretName
    )
    
    Write-Host "`nChecking if secret exists in Key Vault: $VaultName" -ForegroundColor Cyan
    
    ## Get all secrets in one operation to avoid multiple long-running tasks
    try {
        Write-Host "Retrieving all secrets from vault..." -ForegroundColor Gray
        $allSecrets = az keyvault secret list --vault-name $VaultName --query "[].name" -o tsv 2>$null
        
        if ( $LASTEXITCODE -ne 0 -or -not $allSecrets ) {
            Write-Warning "Could not retrieve secrets from vault '$VaultName' - vault may not exist or you may lack permissions"
            
            return $false
        }
        
        $secretList = $allSecrets -split "`r`n" | Where-Object { $_ -ne "" }
        
        ## First try exact match (case-sensitive)
        $exactMatch = $secretList | Where-Object { $_ -eq $SecretName }
        
        if ( $exactMatch ) {
            Write-Warning "Secret '$SecretName' already exists in vault '$VaultName' (exact match)"
            
            return $true
        }
        
        ## Then try case-insensitive exact match
        $caseInsensitiveMatch = $secretList | Where-Object { $_.ToLower() -eq $SecretName.ToLower() }
        
        if ( $caseInsensitiveMatch ) {
            Write-Warning "Secret '$caseInsensitiveMatch' already exists in vault '$VaultName' (case-insensitive match)"
            
            return $true
        }
        
        Write-Host "Secret '$SecretName' does not exist in vault '$VaultName'" -ForegroundColor Gray
        
        return $false
    }
    catch {
        Write-Warning "Could not check secret existence: $($_.Exception.Message)"
        
        return $false
    }
}

function Set-KeyVaultSecret {
    param(
        [string]$VaultName,
        [string]$SecretName,
        [string]$SecretValue,
        [bool]$IsDryRun,
        [bool]$SkipConfirmation
    )
    
    Write-Host "`nUpdating secret in Key Vault: $VaultName" -ForegroundColor Cyan
    
    ## Mask the secret value for display (show first 5 chars + asterisks)
    $maskedValue = if ( $SecretValue.Length -gt 5 ) {
        $SecretValue.Substring(0, 5) + "*" * ($SecretValue.Length - 5)
    }
    else {
        "*" * $SecretValue.Length
    }
    
    Write-Host "  Vault: $VaultName" -ForegroundColor White
    Write-Host "  Secret Name: $SecretName" -ForegroundColor White
    Write-Host "  Secret Value: $maskedValue" -ForegroundColor DarkYellow
    
    if ( $IsDryRun ) {
        Write-Host "[DRY RUN] Would set secret '$SecretName' in vault '$VaultName' to new value" -ForegroundColor Yellow
        
        return $true
    }
    
    if ( -not $SkipConfirmation ) {
        Write-Warning "This will set/update the secret in Azure Key Vault."
        $confirmation = Read-Host "Do you want to proceed? (y/N)"
        
        if ( $confirmation -ne 'y' -and $confirmation -ne 'Y' ) {
            Write-Host "Operation cancelled by user." -ForegroundColor Red
            
            return $false
        }
    }
    
    ## Set the secret in Key Vault
    try {
        $result = az keyvault secret set --vault-name $VaultName --name $SecretName --value $SecretValue --query "id" -o tsv 2>$null
        
        if ( $LASTEXITCODE -eq 0 ) {
            Write-Host "Secret '$SecretName' successfully updated in vault '$VaultName'" -ForegroundColor Green
            
            if ( $result -and $result.StartsWith("https://") ) {
                Write-Debug "Secret ID: $result"
            }
            
            return $true
        }
        else {
            Write-Error "Failed to set secret. Azure CLI returned exit code $LASTEXITCODE"
            Write-Warning "This could be due to insufficient permissions or the vault not existing."
            
            return $false
        }
    }
    catch {
        Write-Error "Error setting secret in Key Vault: $($_.Exception.Message)"
        
        return $false
    }
}

function Show-Summary {
    param(
        [string]$AppName,
        [string]$AppId,
        [string]$VaultName,
        [string]$SecretName,
        [bool]$IsDryRun,
        [bool]$Success
    )
    
    Write-Host "`n"
    Write-Host "OPERATION SUMMARY" -ForegroundColor Magenta
    Write-Host "`n"
    
    Write-Host "App Registration: $AppName" -ForegroundColor White
    Write-Host "App ID: $AppId" -ForegroundColor White
    Write-Host "Key Vault: $VaultName" -ForegroundColor White
    Write-Host "Secret Name: $SecretName" -ForegroundColor White
    Write-Host "Mode: $(if ($IsDryRun) { 'DRY RUN' } else { 'LIVE' })" -ForegroundColor $(if ($IsDryRun) { 'Yellow' } else { 'Green' })
    Write-Host "Status: $(if ($Success) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($Success) { 'Green' } else { 'Red' })
    Write-Host "Completed: $([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White

    Write-Host "`n"
}

## Main execution
Write-Host "`n"
Write-Host "AZURE APP REGISTRATION SECRET ROTATION" -ForegroundColor Magenta
Write-Host "`n"

Write-Host "App Registration: $AppRegistrationName" -ForegroundColor Yellow
Write-Host "Key Vault: $Vault" -ForegroundColor Yellow
Write-Host "Secret Name: $SecretName" -ForegroundColor Yellow
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Green' })

## Validate prerequisites
if ( -not ( Test-AzureCli ) ) {
    exit 1
}

## Get App Registration ID
$appId = Get-AppRegistrationId -DisplayName $AppRegistrationName

if ( -not $appId ) {
    Write-Error "Cannot proceed without valid app registration ID"
    Show-Summary -AppName $AppRegistrationName -AppId "N/A" -VaultName $Vault -SecretName $SecretName -IsDryRun $DryRun -Success $false
    
    exit 1
}

## Check if secret exists in Key Vault
$null = Test-KeyVaultSecret -VaultName $Vault -SecretName $SecretName

## Reset the secret
$newSecret = Reset-AppRegistrationSecret -AppId $appId -IsDryRun $DryRun
if ( -not $newSecret ) {
    Write-Error "Cannot proceed without valid secret"
    
    Show-Summary -AppName $AppRegistrationName -AppId $appId -VaultName $Vault -SecretName $SecretName -IsDryRun $DryRun -Success $false
    
    exit 1
}

## Update Key Vault
$success = Set-KeyVaultSecret -VaultName $Vault -SecretName $SecretName -SecretValue $newSecret -IsDryRun $DryRun -SkipConfirmation $Force
if ( -not $success ) {
    Write-Error "Failed to update Key Vault secret"
    
    Show-Summary -AppName $AppRegistrationName -AppId $appId -VaultName $Vault -SecretName $SecretName -IsDryRun $DryRun -Success $false
    
    exit 1
}

## Show final summary
Show-Summary -AppName $AppRegistrationName -AppId $appId -VaultName $Vault -SecretName $SecretName -IsDryRun $DryRun -Success $true

if ($DryRun) {
    Write-Host "`nTo execute this operation for real, run the same command without -DryRun" -ForegroundColor Cyan
}
else {
    Write-Host "`nSecret rotation completed successfully!" -ForegroundColor Green
}
