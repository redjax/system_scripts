# Az-StorageManager

## Requirements

- The `Az` Powershell module

```powershell
Install-Module -Name Az -AllowClobber -Force -Scope CurrentUser
```
    - After installing, make sure to authenticate with `Connect-AzAccount`

- The `Az.Storage` module

```powershell
Install-Module -Name Az.Storage -AllowClobber -Force -Scope CurrentUser
```

- The `Az.Accounts` module

```powershell
Install-Module -Name Az.Accounts -AllowClobber -Force -Scope CurrentUser
```

## Setup

- Copy [`params.example.json`] to `params.json`
  - Edit the file, inputting the values for a subscription ID, resource group, storage account, etc.
- Run the script with `.\Hunt-AzureStorage.ps1`

## Links

- [Tackle 0 byte files in Azure Blob Storage with ease using Azure Powershell](https://dev.to/truelime/tackle-0-byte-files-in-azure-blob-storage-with-ease-using-az-powershell-5fb7)
