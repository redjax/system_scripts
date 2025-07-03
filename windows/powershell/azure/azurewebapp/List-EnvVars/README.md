# Azure App Service Environment Variables Extractor

This repository contains PowerShell scripts to extract environment variables from Azure App Services and their deployment slots.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- PowerShell 5.1 or later
- Appropriate permissions to read App Service configurations

## Usage

### Powershell Script

The `Let-AzAppEnvVars.ps1` script iterates over an array of resources (passed as `-Resources @(@{ ResourceGroup = "resourceName"; AppService = "appServiceName" })`) and gathers the environment variables for any slots discovered.

You can define your resources as a variable and pass it to the script.

```powershell
## Define your resources
$resources = @(
    @{ ResourceGroup = "resource-group-name"; AppService = "appService1" },
    @{ ResourceGroup = "resource-group2-name"; AppService = "appService2" },
    @{ ResourceGroup = "resource-group3-name"; AppService = "appService3" }
)

## Run the script
.\List-AzAppEnvVars.ps1 -Resources $resources
```

### Azure CLI

You can also run the Azure CLI commands directly.

#### List Azure App Service slots

```shell
az webapp deployment slot list `
    --name $AppService `
    --resource-group $ResourceGroup `
    --query "[].name" `
    -o tsv
```

#### List slot settings for production (default) slot

```shell
az webapp config appsettings `
    list --name "appServiceName" `
    --resource-group "resourceGroupName" `
    --output json
```

#### List slot settings for other slots

```shell
az webapp config appsettings list `
    --name "appServiceName" `
    --resource-group "resourceGroupName" `
    --slot "slotName" `
    --output json
```
