# Search Azure Storage Account

Script to search Azure Storage for a file pattern. Downloads a list of all files to a local `blob_manifest.json` (or whatever filename you pass with `-ManifestFilePath`), loads the JSON content into a `PSCustomObject` class, and iterates over the manifest to find the file matching your search string.

## Usage

Before using this script, you must have the [`az` CLI tool](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli) installed, and you must authenticate with `az login`. **The account you authenticate with must have READ permissions to the Azure Storage Account you are querying.**

This script requires 4 inputs:

- `-ResourceGroupName`: The name of the resource group where the Azure Storage account exists.
- `StorageAccountName`: The name of the Storage Account resource in the resource group defined above.
- `ContainerName`: The name of the container to search in the Storage Account.
- `SearchString`: Your search string for the file you want to find.
  - Examples:
    - `-SearchString 20241202_some_file.csv` - search for a file matching the name `20241202_some_file.csv`
    - `-SearchString *.wav` - search for all `.wav` files
    - `-SearchString *filename part*.txt` - search for any text files with `filename part` somewhere in the name.

You can also pass optional switches `-Debug` (to enable debug messages) and `-Cleanup` (to remove the `blob_manifest.json` file after execution).
