# App Registration Secret Rotation Guide

This document outlines the manual process for rotating an app registration secret, updating Azure KeyVault, and restarting associated web apps or function apps.

## Prerequisites

- Azure CLI installed and authenticated
- Appropriate permissions to:
  - Manage app registrations in Azure AD
  - Update secrets in Azure KeyVault
  - Restart web apps and function apps

## Secret Rotation Process

### Step 1: Find the App Registration

```powershell
# Search for app registrations by partial name (e.g., "PartialAppName")
az ad app list --all --query "[?contains(displayName, 'PartialAppName')].{id:appId, name:displayName}" -o tsv

# For apps with special prefixes like EpiMHA, you might need more specific queries:
az ad app list --all --query "[?contains(displayName, 'EpiMHA.PartialAppName')].{id:appId, name:displayName}" -o tsv

# Or directly search by exact name if known:
az ad app list --display-name "EpiMHA.PartialAppName-np/dev" --query "[].{id:appId, name:displayName}" -o tsv
```

### Step 2: Reset the App Registration Secret

```powershell
# Once you've found the app registration ID, reset its secret
$appId = "YOUR-APP-ID"  # Replace with the app ID from step 1
$newSecret = az ad app credential reset --id "$appId" --query "password" -o tsv

# Display the new secret (be careful with this in production environments)
Write-Host "New Secret: $newSecret"
```

### Step 3: Update Secret in Azure KeyVault

```powershell
# Determine environment from app name
# For example:
# - Names with "-np/dev" → dev environment
# - Names with "-np" → rc environment
# - Names with "-p" → prod environment

# Set environment and clean app name
$environment = "dev"  # Change as needed: "dev", "rc", "prod", "ext-test"
$cleanAppName = "PartialAppName"  # Clean app name without prefixes/suffixes

# Update KeyVault
$keyVaultName = "epi-secrets-$environment"
$secretName = "AzureAd${cleanAppName}--ClientSecret"

az keyvault secret set --name $secretName --vault-name $keyVaultName --value "$newSecret"
Write-Host "Secret updated in KeyVault: $keyVaultName"
```

### Step 4: Find Associated Web App or Function App

```powershell
# For web apps, try different naming patterns
$webAppPatterns = @(
    "Epi${cleanAppName}-np",  # For dev/rc
    "Epi${cleanAppName}-p",   # For prod
    "EpiMHA.${cleanAppName}-np", 
    "EpiMHA.${cleanAppName}-p"
)

foreach ($pattern in $webAppPatterns) {
    Write-Host "Searching for web app: $pattern"
    az webapp list --query "[?contains(name, '$pattern')].{name:name, resourceGroup:resourceGroup}" -o table
}

# Similarly for function apps
$functionAppPatterns = @(
    "Epi${cleanAppName}-np-dev",  # For dev
    "Epi${cleanAppName}-np",      # For rc
    "Epi${cleanAppName}-p",       # For prod
    "epi${cleanAppName}-np-dev",  # Lowercase versions
    "epi${cleanAppName}-np",
    "epi${cleanAppName}-p"
)

foreach ($pattern in $functionAppPatterns) {
    Write-Host "Searching for function app: $pattern"
    az functionapp list --query "[?contains(name, '$pattern')].{name:name, resourceGroup:resourceGroup}" -o table
}
```

### Step 5: Restart the Web App or Function App

```powershell
# For web apps
$webAppName = "YourWebAppName"  # From step 4
$resourceGroup = "YourResourceGroup"  # From step 4

# For dev environments, you might need to specify a slot
$isDevEnvironment = $true  # Set based on app name/environment
if ($isDevEnvironment) {
    az webapp restart --name $webAppName --resource-group $resourceGroup --slot dev
} else {
    az webapp restart --name $webAppName --resource-group $resourceGroup
}

# For function apps
$functionAppName = "YourFunctionAppName"  # From step 4
$functionAppResourceGroup = "YourFunctionAppResourceGroup"  # From step 4

az functionapp restart --name $functionAppName --resource-group $functionAppResourceGroup
```

## Common App Naming Conventions

- **App Registrations**:
  - Development: `Epi{AppName}-np/dev` or `EpiMHA.{AppName}-np/dev`
  - RC/Testing: `Epi{AppName}-np` or `EpiMHA.{AppName}-np`
  - Production: `Epi{AppName}-p` or `EpiMHA.{AppName}-p`
  - External: `Epi{AppName}-np-external`

- **Web Apps**:
  - Development: Use base name + slot: `Epi{AppName}-np` with slot `dev`
  - RC/Testing: `Epi{AppName}-np`
  - Production: `Epi{AppName}-p`
  - External: `Epi{AppName}-ext-test`

- **Function Apps**:
  - Development: `Epi{AppName}-np-dev` or `epi{AppName}-np-dev`
  - RC/Testing: `Epi{AppName}-np` or `epi{AppName}-np`
  - Production: `Epi{AppName}-p` or `epi{AppName}-p`
  - External: `Epi{AppName}-ext-test` or `epi{AppName}-ext-test`

## KeyVault Naming Conventions

- Development: `epi-secrets-dev`
- RC/Testing: `epi-secrets-rc`
- Production: `epi-secrets-prod`
- External: `epi-secrets-ext-test`

## Secret Naming Conventions

- Standard format: `AzureAd{CleanAppName}--ClientSecret`
  - Example: `AzureAdPartialAppName--ClientSecret`

## Troubleshooting Tips

- If you're having trouble finding resources with exact name matches, try using wildcards or partial matches with the `contains()` function in Azure CLI queries.
- For app registrations with special characters (like '.') in their name, try direct lookup by display name.
- If web apps aren't found, check both uppercase and lowercase versions of the name.
- For apps with multiple instances across environments, make sure you're operating on the correct one by verifying the resource group and environment suffix.
- Check Azure Activity Logs if the restart command doesn't appear to take effect.

## Security Notes

- Always rotate secrets safely and securely store the new secrets.
- Minimize the time between secret rotation and app restart to reduce potential downtime.
- Consider using automation for routine secret rotation to reduce human error.
- Verify the apps are functioning correctly after the restart.
