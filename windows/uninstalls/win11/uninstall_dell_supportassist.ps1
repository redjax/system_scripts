<#
    Query registry for uninstall strings for Dell SupportAssist apps, run uninstall strings with cmd.
#>

## Set this to '1' to output debug messages as script runs
#  Wrap 'Write-Host' debug messages in IF statement like If ($DEBUG_MSG -eq 1) { Write-Host "Debug message" }
$DEBUG_MSG = 0

## Get all SupportAssist installed versions from registry
$SAVer = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall  |
Get-ItemProperty |
Where-Object { $_.DisplayName -match "SupportAssist" } |
Select-Object -Property DisplayName, DisplayVersion, UninstallString, PSChildName

## Array to store uninstall strings
$UninstallObjs = @()

## Loop over $SAVer object to get uninstall strings
ForEach ($ver in $SAVer) {

    ## If an uninstall string is available
    If ($ver.UninstallString) {

        ## Get DisplayName
        $displayname = $ver.DisplayName
        ## Get version
        $version = $ver.DisplayVersion
        ## Get uninstall string
        $uninst = $ver.UninstallString

        If ( $DEBUG_MSG -eq 1 ) {
            Write-Host "[DEBUG] Display name: $displayname"
            Write-Host "[DEBUG] Version: $version"
            Write-Host "[DEBUG] Uninstall string: $uninst"
        }

        ## Create object to add to $UninstallObjs
        $UninstallObjs += New-Object psobject -Property @{
            ## App name
            name             = $displayname
            ## App version
            version          = $version
            ## App uninstall string
            uninstall_string = $uninst
        }

    }
}

## Loop over objects in $UninstallObjs, run uninstall string
ForEach ($obj in $UninstallObjs) {

    If ( $DEBUG_MSG -eq 1 ) {
        Write-Host "[DEBUG][`$UninstallObjs.obj] Name:" $obj.name
        Write-Host "[DEBUG][`$UninstallObjs.obj] Version:" $obj.version
        Write-Host "[DEBUG][`$UninstallObjs.obj] Uninstall string:" $obj.uninstall_string
    }

    Write-Host "Uninstalling" $obj.name
    Write-Host "Uninstall command: cmd /c" $obj.uninstall_string "/quiet /norestart"
    
    $ArgList = "/C " + $obj.uninstall_string + " /quiet /norestart"
    
    If ( $DEBUG_MSG -eq 1 ) {
        Write-Host "[DEBUG] Args: $ArgList"
    }

    ## Use Start-Process to start a cmd prompt & pass $ArgList with uninstall string, wait for finish
    Start-Process cmd -ArgumentList $ArgList -Wait

}
