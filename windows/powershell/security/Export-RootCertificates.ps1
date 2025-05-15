Param(
    [Parameter(Mandatory = $false, HelpMessage = "Path to a directory where the exported root certificates will be saved.")]
    [string]$OutputPath = "C:\temp",
    [Parameter(Mandatory = $false, HelpMessage = "Name of the output file for the exported root certificates.")]
    [string]$OutputFilename = "roots.sst"
)

$OutputPath = Join-Path -Path $OutputPath -ChildPath $OutputFilename

try {
    certutil -generateSSTFromWU "$($OutputPath)"
} catch {
    Write-Error "Error exporting root certificates: $($_.Exception.Message)"
}