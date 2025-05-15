[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "C:\temp",

    [Parameter(Mandatory = $false)]
    [string]$OutputFilename = "roots.sst",

    [Parameter(Mandatory = $false)]
    [switch]$ConvertToPEM
)

## Script paths
$OutputFile = Join-Path -Path $OutputPath -ChildPath $OutputFilename
$pemFile = Join-Path -Path $OutputPath -ChildPath "roots.pem"
$splitDir = Join-Path -Path $OutputPath -ChildPath "roots_split"
$tempDir = Join-Path -Path $OutputPath -ChildPath "certs_temp"

function Start-Cleanup {
    <#
        Run cleanup tasks at end of script to remove files created in $OutputPath.

        Leaves the split_roots/ directory where certificates are stored, if -ConvertToPEM is used.
    #>
    Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
    ## Remove exported root certificates file
    Remove-Item -Path $OutputFile -Recurse -Force -ErrorAction SilentlyContinue
    ## Remove certs_temp/ directory that script creates
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    ## Remove roots.pem file (created if -ConvertToPEM is used)
    Remove-Item -Path ( Join-Path -Path $OutputPath -ChildPath "roots.pem" ) -Recurse -Force -ErrorAction SilentlyContinue
}

function Export-RootCertificates {
    <#
        Export root certificates using certutil
    #>
    
    try {
        certutil -generateSSTFromWU "$OutputFile"
        Write-Host "Certificates exported to $OutputFile" -ForegroundColor Green
    }
    catch {
        Write-Error "Error exporting root certificates: $($_.Exception.Message)"
        exit 1
    }

}

## Call function to export root certificates
Export-RootCertificates

## Convert to Linux PEM format if -ConvertToPEM is used
if ( $ConvertToPEM ) {
    ## Ensure script was run as administrator
    if ( -not (
            [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    ) {
        Write-Error "This script must be run as Administrator. Please right-click PowerShell and select 'Run as Administrator'."
        exit 1
    }

    ## Find OpenSSL
    $opensslExe = $null
    $osslShiningLight = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"
    $osslGit = "C:\Program Files\Git\usr\bin\openssl.exe"

    if ( Test-Path $osslShiningLight ) {
        ## Use C:\Program Files path
        $opensslExe = $osslShiningLight
        Write-Host "Using OpenSSL from Shining Light install: $opensslExe" -ForegroundColor Cyan
    }
    elseif ( Test-Path $osslGit ) {
        ## Use openssl binary embedded in Git installation
        $opensslExe = $osslGit
        Write-Host "Using OpenSSL from Git for Windows: $opensslExe" -ForegroundColor Cyan
    }
    else {
        ## No OpenSSL found

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

    ## Create directories for temp files and split certificates
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    New-Item -ItemType Directory -Path $splitDir -Force | Out-Null

    Write-Host "Converting certificates to PEM format..." -ForegroundColor Magenta

    try {
        ## Import certificates from SST file
        $certificates = Import-Certificate -FilePath $OutputFile -CertStoreLocation Cert:\LocalMachine\Root

        ## Create temporary store to hold imported certificates
        $tempStore = New-Object System.Security.Cryptography.X509Certificates.X509Store(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            "LocalMachine"
        )
        $tempStore.Open("ReadWrite")
        
        ## Create collection and add certificates properly
        $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $certCollection.AddRange($certificates)
        $tempStore.AddRange($certCollection)

        ## Export individual certificates
        Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
            $cert = $_
            $tempCer = Join-Path -Path $tempDir -ChildPath "$($cert.Thumbprint).cer"
            $tempPem = Join-Path -Path $tempDir -ChildPath "$($cert.Thumbprint).pem"
            
            Export-Certificate -Cert $cert -FilePath $tempCer -Type CERT | Out-Null
            & "$opensslExe" x509 -inform der -in $tempCer -out $tempPem
        }

        ## Combine PEM files
        Get-ChildItem $tempDir\*.pem | ForEach-Object {
            Add-Content -Path $pemFile -Value (Get-Content $_.FullName)
            Add-Content -Path $pemFile -Value ""
        }

        ## Split combined PEM into individual CRT files
        Write-Host "Splitting PEM file into individual certificates..." -ForegroundColor Cyan
        $certIndex = 1
        $certLines = @()
        $inCert = $false

        ## Read the combined PEM file and split into individual certificates
        Get-Content $pemFile | ForEach-Object {
            if ($_ -match "^-+BEGIN CERTIFICATE-+$") {
                $inCert = $true
                $certLines = @($_)
            }
            elseif ($_ -match "^-+END CERTIFICATE-+$") {
                $certLines += $_
                $outFile = Join-Path $splitDir ("root-cert-{0:D3}.crt" -f $certIndex)
                $certLines | Set-Content -Encoding ascii $outFile
                $certIndex++
                $inCert = $false
            }
            elseif ($inCert) {
                $certLines += $_
            }
        }

        Write-Host "Certificates converted to PEM format at $pemFile" -ForegroundColor Green
        Write-Host "Split certificates created in: $splitDir" -ForegroundColor Green
        Write-Host @"
Next steps:

  1. Open WSL and copy split certificates to /usr/local/share/ca-certificates/
        sudo cp /mnt/c/temp/roots_split/*.crt /usr/local/share/ca-certificates/

  2. Install the ca-certificates package in WSL (if not already installed)
        (Debian/Ubuntu) sudo apt-get install ca-certificates
        (Fedora) sudo dnf install ca-certificates
        (Alpine) sudo apk add ca-certificates
  
  3. Run update-ca-certificates to update the CA store in WSL.
        sudo update-ca-certificates

  4. Verify installation (optional)
        ls -l /etc/ssl/certs/ | grep -i roots
"@ -ForegroundColor Green

    }
    catch {
        Write-Error "Failed to convert certificates: $($_.Exception.Message)"
        exit 1
    }
    finally {
        ## Close temporary store if it's still open
        if ( $tempStore ) {
            $tempStore.Close()
        }

        ## Run cleanup tasks
        Start-Cleanup
    }
}
