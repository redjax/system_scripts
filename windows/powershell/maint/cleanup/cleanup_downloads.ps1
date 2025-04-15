Param(
    [string[]]$ExcludeDirs = @("_keep"),
    [switch]$DryRun
)

$DownloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
Write-Output "Downloads path: $DownloadsPath"

$DownloadsSearchResults = (Get-ChildItem -Path $DownloadsPath | Where-Object { $_.Name -notin $ExcludeDirs })
# $DownloadsSearchResults | Format-Table -Property Name, Mode, LastWriteTime, Length

$DeleteObjects = foreach ($item in $DownloadsSearchResults) {
    [PSCustomObject]@{
        Name         = $item.Name
        FullPath     = $item.FullName
        Type         = if ($item.PSIsContainer) { "Directory" } else { "File" }
        LastWriteTime= $item.LastWriteTime
        Size         = if ($item.PSIsContainer) { $null } else { $item.Length }
    }
}

Write-Output "Found $($DownloadsSearchResults.Count) file(s)."
$DeleteObjects | Format-Table -Property Type, Size, FullPath -AutoSize

if ( $DryRun ) {
    $DeleteObjects | ForEach-Object {
        Write-Output "Would delete $($_.Type.ToLower()): $($_.FullPath)"
    }
    
} else {
    Write-Output "Deleting $($DownloadsSearchResults.Count) file(s)."
    $DeleteObjects | ForEach-Object {
        try {
            Remove-Item -Path $_.FullPath -Recurse -Force
            Write-Output "Deleted file: $($_.FullPath)"
        } catch {
            Write-Error "Error deleting file: $($_.FullName). Details: $($_.Exception.Message)"
            continue
        }
    }
}
