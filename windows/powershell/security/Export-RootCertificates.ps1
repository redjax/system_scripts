[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\temp",

    [Parameter(Mandatory = $false)]
    [string]$OutputFilename = "roots.sst",

    [Parameter(Mandatory = $false)]
    [switch]$ConvertToPEM
)

$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputFilename
$pemFile = Join-Path -Path $OutputPath -ChildPath "roots.pem"
$tempDir = Join-Path -Path $OutputPath -ChildPath "certs_temp"

## Export root certificates using certutil
try {
    certutil -generateSSTFromWU "$OutputFile"
    Write-Host "Certificates exported to $OutputFile" -ForegroundColor Green
}
catch {
    Write-Error "Error exporting root certificates: $($_.Exception.Message)"
    exit 1
}

if ($ConvertToPEM) {
    ## Ensure script was run as administrator
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script must be run as Administrator. Please right-click PowerShell and select 'Run as Administrator'."
        exit 1
    }

    # Find OpenSSL
    $opensslExe = $null
    $osslShiningLight = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
    $osslGit = "C:\Program Files\Git\usr\bin\openssl.exe"

    if (Test-Path $osslShiningLight) {
        $opensslExe = $osslShiningLight
        Write-Host "Using OpenSSL from Shining Light install: $opensslExe" -ForegroundColor Cyan
    } elseif (Test-Path $osslGit) {
        $opensslExe = $osslGit
        Write-Host "Using OpenSSL from Git for Windows: $opensslExe" -ForegroundColor Cyan
    } else {
        Write-Error @"
OpenSSL was not found in either:
  $osslShiningLight
or
  $osslGit

Please install OpenSSL (winget install -e --id=ShiningLight.OpenSSL.Light)
or Git for Windows (which includes OpenSSL).
"@
        exit 1
    }

    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    Write-Host "Converting certificates to PEM format..." -ForegroundColor Magenta

    try {
        # Import certificates from SST file
        $certificates = Import-Certificate -FilePath $OutputFile -CertStoreLocation Cert:\LocalMachine\Root

        $tempStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            "LocalMachine"
        )
        $tempStore.Open("ReadWrite")
        
        # Create collection and add certificates properly
        $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $certCollection.AddRange($certificates)
        $tempStore.AddRange($certCollection)

        # Export individual certificates
        Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
            $cert = $_
            $tempCer = Join-Path -Path $tempDir -ChildPath "$($cert.Thumbprint).cer"
            $tempPem = Join-Path -Path $tempDir -ChildPath "$($cert.Thumbprint).pem"
            
            Export-Certificate -Cert $cert -FilePath $tempCer -Type CERT | Out-Null
            & "$opensslExe" x509 -inform der -in $tempCer -out $tempPem
        }

        # Combine PEM files
        Get-ChildItem $tempDir\*.pem | ForEach-Object {
            Add-Content -Path $pemFile -Value (Get-Content $_.FullName)
            Add-Content -Path $pemFile -Value ""
        }

        Write-Host "Certificates converted to PEM format at $pemFile" -ForegroundColor Green
        Write-Host @"
Next steps:

  1. Open WSL and copy your converted certificates to /usr/local/share/ca-certificates/roots.crt (example below assumes c:\temp for the output path)
        cp /mnt/c/temp/roots.pem /usr/local/share/ca-certificates/roots.crt
  3. Install the ca-certificates package in WSL (if not already installed)
        (Debian/Ubuntu) sudo apt-get install ca-certificates
        (Fedora) sudo dnf install ca-certificates
        (Alpine) sudo apk add ca-certificates
  2. Run update-ca-certificates to update the CA store in WSL.
        update-ca-certificates
"@ -ForegroundColor Green

    }
    catch {
        Write-Error "Failed to convert certificates: $($_.Exception.Message)"
        exit 1
    }
    finally {
        if ($tempStore) {
            $tempStore.Close()
        }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}