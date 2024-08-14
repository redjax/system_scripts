function Read-WingetAppFile {
    <# 
        Read the contents of a JSON file with Winget apps.

        App keys:
            - name
            - id
            - description

        Load each app into a PSCustomObject and return list of apps.
    #>
    param (
        [string]$JsonFilePath,
        [switch]$Debug
    )

    if ($Debug) {
        Write-Debug "Reading JSON file: $JsonFilePath"
    }

    # Read the JSON file and convert it to objects
    $jsonContent = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json

    # Create an array of PSCustomObjects
    $appObjects = @()
    foreach ($app in $jsonContent) {
        # Create a new PSCustomObject for each app
        $appObject = [PSCustomObject]@{
            Name        = $app.name
            Id          = $app.id
            Description = $app.description
        }

        $appObjects += $appObject
    }

    return $appObjects
}