# Get-SystemSpecReport

A script to generate a report on the host environment. Gathers information about the OS, Powershell environment, and hardware information including CPU, GPU, and drives.

## Usage

Run with `-Help` param to print help menu.

```powershell
.\Get-SystemSpecReport.ps1 [-Save] [-Debug] [-OutputDirectory <c:\path\to\report\directory] [-OutputFilename <nameOfFileWithoutExtension>] [-OutputFormat <json,xml,txt>]
```

If `-Save` is passed, by default a report will be saved to `${env:USERPROFILE}\SystemReport\SystemReport.json`. This path can be tweaked by passing the following params:

- `-OutputDirectory`: (Default: `${env:USERPROFILE}\`) The destination directory/folder where the file will be saved.
- `-OutputFilename`: (Default: `SystemReport`) The name of the file, without file extension (i.e. to save `SystemReport.json`, pass `-OutputFilename SystemReport` `-OutputFormat json`)
- `-OutputFormat`: (Default: `json`, Options: `json,xml,txt`) The file format for the outputted file.

`-Help` output:

```powershell
## $> Get-SystemSpecReport -Help

[[ Get-SystemSpecReport Help ]]
-------------------------------

Compile a report of system information, including OS & Powershell environment, CPU, GPU, GRAM, disks, and motherboard. Optionally export to a file with -Save.

[Params]

-Save: Save report to file.
-Debug: Enable debug mode.
-OutputDirectory: Specify the output directory for the report file.
-OutputFilename: Specify the filename for the report file.
-OutputFormat: Specify the format for the report file (json, xml, txt).

Example: Save report to C:\Temp\SystemReport.xml
    $> .\Get-SystemSpecReport.ps1 -Save -OutputDirectory C:\Temp -OutputFilename SystemReport -OutputFormat xml
```
