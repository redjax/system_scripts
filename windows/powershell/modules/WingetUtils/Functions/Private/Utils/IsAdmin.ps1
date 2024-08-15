function Is-Admin {
    <# Return $true if shell is elevated, else return $false #>
    # Get the current Windows identity
    [CmdletBinding()]
    Param()
    $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    
    # Create a Windows principal based on the current identity
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
    
    # Check if the current user is in the Administrators group
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}