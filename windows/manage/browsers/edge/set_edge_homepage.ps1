<#
    Reference: https://gist.github.com/aldodelgado/ab70809ed513fa59c1a50f532d47297a

    Sets Edge browser's homepage to value in $url.
#> 

param(
    # Set URL to become Edge's homepage
    [String] $url = "https://embracepetinsurance.sharepoint.com"
)
## Registry keys

# Test for registry key path's existence
$policyexists = Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Edge
$policyexistshome = Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Edge\RestoreOnStartupURLs

# Set path to registry key
$regKeysetup = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$regKeyhome = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\RestoreOnStartupURLs"



## Setup policy dirs in registry (if needed). Set password
#  manager, else sets them to the correct values if they already exist
If ($policyexists -eq $false) {

    ## Edge Policies key does not exist, create and set properties
    New-Item -path HKLM:\SOFTWARE\Policies\Google
    New-Item -path HKLM:\SOFTWARE\Policies\Microsoft\Edge

    New-ItemProperty -path $regKeysetup -Name PasswordManagerEnabled -PropertyType DWord -Value 0
    New-ItemProperty -path $regKeysetup -Name RestoreOnStartup -PropertyType Dword -Value 4
    New-ItemProperty -path $regKeysetup -Name HomepageLocation -PropertyType String -Value $url
    New-ItemProperty -path $regKeysetup -Name HomepageIsNewTabPage -PropertyType DWord -Value 0

}

Else {

    ## Edge Policies key does exist, set properties

    Set-ItemProperty -Path $regKeysetup -Name PasswordManagerEnabled -Value 0
    Set-ItemProperty -Path $regKeysetup -Name RestoreOnStartup -Value 4
    Set-ItemProperty -Path $regKeysetup -Name HomepageLocation -Value $url
    Set-ItemProperty -Path $regKeysetup -Name HomepageIsNewTabPage -Value 0

}

## This entry requires a subfolder in the registry.
#  For more than one page, create another new-item and
#  set-item line with the name -2 and the new url
if ($policyexistshome -eq $false) {
    ## Key does not exist. Create and set property
    
    New-Item -path HKLM:\SOFTWARE\Policies\Microsoft\Edge\RestoreOnStartupURLs
    New-ItemProperty -path $regKeyhome -Name 1 -PropertyType String -Value $url

}

Else {
    ## Key does exist, set property

    Set-ItemProperty -Path $regKeyhome -Name 1 -Value $url

}
