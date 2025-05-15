# Export Root Certificates

If you are on a company network and get TLS errors when trying to download things in WSL with `wget` or installing packages with Python, Go, or your system's package manager, the [`Export-RootCertificates.ps1` script](./Export-RootCertificates.ps1) can help by exporting your Windows root certificates for you to import into WSL.

If you are using a company VPN like Edge Guardian or ZScaler, this script will install the VPN's root certificate from Windows into your WSL container.

**!! This script requires admin/root privileges on both the Windows and Linux side !!**

## Usage

* Save the [`Export-RootCertificates.ps1` script](./Export-RootCertificates.ps1) to your machine (or copy/paste the contents into a new file).
* Open a Powershell session as an administrator
* Run `Get-Help path/to/Export-RootCertificates.ps1` to see the script's help menu
* Run `./path/to/Export-RootCertificates.ps1 -ConvertToPEM`
  * This will export your trusted root certificates from Windows, convert them to PEM format with OpenSSL, and split the root certificates so they can be imported in a WSL container.
  * The script will output instructions for installing these certificates in WSL once it finishes running.
