try {
    certutil -generateSSTFromWU roots.sst
} catch {
    Write-Error "Error exporting root certificates: $($_.Exception.Message)"
}