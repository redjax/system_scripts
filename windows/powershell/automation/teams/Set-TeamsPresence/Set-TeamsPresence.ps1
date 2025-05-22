[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "UPN of user to set presence for. If not provided, the current user's UPN will be used. Example: username@domain.com")]
    [string]$UPN = $null,
    [Parameter(Mandatory = $false, HelpMessage = "Presence status to set. Options: Available, Busy, Away, DoNotDisturb, BeRightBack, OffWork, Offline, InACall, InAConferenceCall. Default is 'Available'.")]
    [ValidateSet('Available', 'Busy', 'Away', 'DoNotDisturb', 'BeRightBack', 'OffWork', 'Offline', 'InACall', 'InAConferenceCall')]
    [string]$Presence,
    ## ISO8601 duration, default 1 hour
    [Parameter(Mandatory = $false, HelpMessage = "Duration for presence. Default is 1 hour. Example: PT1H (1 hour), PT30M (30 minutes)")]
    [string]$Duration = "PT1H"
)

Write-Host "Checking for Microsoft.Graph module." -ForegroundColor Cyan
## Check if Microsoft.Graph module is installed, if not, install it
if ( -not ( Get-Module -ListAvailable -Name "Microsoft.Graph" ) ) {
    Write-Host "Microsoft.Graph module not found. Installing" -ForegroundColor Yellow
    try {
        Install-Module Microsoft.Graph -Scope CurrentUser -Force
        Write-Host "Microsoft.Graph module installed." -ForegroundColor Green
    } catch {
        Write-Error "Unable to install Microsoft.Graph module. Please install it manually. Error details: $($_.Exception.Message)"
        exit 1
    }
}
Write-Host "Microsoft.Graph module found. Importing" -ForegroundColor Cyan
try {
    Import-Module Microsoft.Graph
    Write-Host "Microsoft.Graph module imported." -ForegroundColor Green
} catch {
    Write-Error "Unable to import Microsoft.Graph module. Please install it manually. Error details: $($_.Exception.Message)"
    exit 1
}
Write-Host "Microsoft.Graph module imported." -ForegroundColor Green

## Connect to Microsoft Graph with required scopes
Write-Host "Connecting to Microsoft Graph with required scopes..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes "Presence.ReadWrite.All","User.Read.All"
    Write-Host "Connected to Microsoft Graph." -ForegroundColor Green
} catch {
    Write-Error "Unable to connect to Microsoft Graph. Please check your permissions and try again. Error details: $($_.Exception.Message)"
    exit 1
}

## Set UPN to current user if not provided
if ( -Not ( $UPN ) ) {
    try {
        $UPN = (Get-MgUser -UserId 'me').UserPrincipalName
        Write-Host "UPN: $UPN"
    } catch {
        Write-Error "Unable to retrieve current user's UPN. Please provide a UPN. Error details: $($_.Exception.Message)"
        exit 1
    }
}

if ( -Not $UPN ) {
    Write-Error "UPN is empty, indicating an issue with authentication. Please check your credentials and permissions, and try again. Your tenant may not have the required permission 'Presence.ReadWrite.All' granted to the application. If this is the case, you will need to work with your administrator to enable that before this script will work."
    exit 1
}

try {
    ## Get the user object
    $user = Get-MgUser -UserId $UPN -ErrorAction Stop
} catch {
    Write-Error "Unable to retrieve user object for UPN. Please check the UPN and try again. Error details: $($_.Exception.Message)"
    exit 1
}

try {
    ## Set the presence via Graph API (beta endpoint)
    $uri = "https://graph.microsoft.com/beta/users/$($user.Id)/presence/setPresence"
    $sessionId = [guid]::NewGuid().ToString()

    $body = @{
        sessionId = $sessionId
        availability = $Presence
        activity = $Presence
        expirationDuration = $Duration
    } | ConvertTo-Json

    ## Get an access token for Graph
    $token = (Get-MgContext).AccessToken
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    ## Set presence
    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -Body $body

    Write-Host "Presence for $UPN set to '$Presence' for $Duration." -ForegroundColor Green
}
catch {
    Write-Error "Error setting Teams presence to '$Presence' for $UPN. Error details: $($_.Exception.Message)"
    exit 1
}
