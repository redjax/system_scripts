Param(
    [Parameter(Mandatory = $false, HelpMessage = "Please enter your username in the format 'DOMAIN\username")]
    [string]$Identity = "$env:USERDOMAIN\$env:USERNAME",
    [Parameter(Mandatory = $false, HelpMessage = "The Exchange UPN for your user (i.e. username@domain.com)")]
    [string]$UPN,
    [Parameter(Mandatory = $false, HelpMessage = "Enter the autoreply state (default: Scheduled)")]
    [string]$AutoReplyState = "Scheduled",
    [Parameter(Mandatory = $false, HelpMessage = "The date/time to start the OOO schedule. Value should be a quoted string, i.e. 'YYYY-MM-dd hh:mm tt'")]
    [datetime]$StartTime,
    [Parameter(Mandatory = $false, HelpMessage = "The date/time to end the OOO schedule. Value should be a quoted string, i.e. 'YYYY-MM-dd hh:mm tt'")]
    [datetime]$EndTime,
    [Parameter(Mandatory = $false, HelpMessage = "Path to a .txt file containing the internal OOO message you want to apply.")]
    [string]$InternalMessageFile = "messages/internal/default.txt",
    [Parameter(Mandatory = $false, HelpMessage = "Path to a .txt file containing the external OOO message you want to apply.")]
    [string]$ExternalMessageFile = "messages/external/default.txt",
    [Parameter(Mandatory = $false, HelpMessage = "When `$false, message will only be displayed, not applied.")]
    [bool]$Apply = $true
)

## Check if the ExchangeOnlineManagement module is installed
if ( -Not ( Get-Module -ListAvailable | Where-Object { $_.Name -like "ExchangeOnlineManagement" } ) ) {
    Write-Error "ExchangeOnlineManagement module not found. Please install with: Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser -Force"
    exit 1
}

## Check that an identity was passed
if ( -Not $Identity ) {
    Write-Error "Missing identity to apply the OOO message to."
    exit 1
}

## Check that a UPN was passed
if ( -Not $UPN ) {
    Write-Error "Missing an Exchange user UPN (i.e. user@domain.com)."
    exit 1
}

## Ensure message file exists
if ( -Not ( Test-Path $InternalMessageFile ) ) {
    Write-Error "Internal message file '$InternalMessageFile' does not exist."
    exit 1
}

## Load message contents
$InternalMessageText = Get-Content $InternalMessageFile -Raw
$ExternalMessageText = Get-Content $ExternalMessageFile -Raw

## Normalize line endings
$InternalMessageText = "<html><body>" + ($InternalMessageText -Replace "`r`n", "<br>") + "</body></html>"
$ExternalMessageText = "<html><body>" + ($ExternalMessageText -Replace "`r`n", "<br>") + "</body></html>"

## Replace placeholder with provided values
$FormattedEndDate = $EndTime.ToString("MM/dd/yy")

if ($InternalMessageText -match '\[date of your return\]') {
    $InternalMessageText = $InternalMessageText -replace '\[date of your return\]', $FormattedEndDate
}
else {
    Write-Warning "Placeholder '[date of your return]' not found in message file."
}

if ($ExternalMessageText -match '\[date of your return\]') {
    $ExternalMessageText = $ExternalMessageText -replace '\[date of your return\]', $FormattedEndDate
}
else {
    Write-Warning "Placeholder '[date of your return]' not found in message file."
}

Write-Host "Scheduled internal message text:`n" -ForegroundColor Cyan -NoNewline; Write-Host "$($InternalMessageText)"
Write-Host "Scheduled external message text:`n" -ForegroundColor Cyan -NoNewline; Write-Host "$($ExternalMessageText)"

if ( $Apply ) {
    ## Import ExchangeOnlineManagement module
    try {
        Import-Module ExchangeOnlineManagement
    }
    catch {
        Write-Error "Error importing module ExchangeOnlineManagement. Details: $($_.Exception.Message)"
        exit 1
    }

    if ( -Not ( Get-Module ExchangeOnlineManagement ) ) {
        Write-Error "Could not import ExchangeOnlineManagement module."
        exit 1
    }

    ## Connect to Exchange
    Write-Host "Connecting to Exchange..." -ForegroundColor Cyan
    try {
        Connect-ExchangeOnline -UserPrincipalName $UPN -ShowProgress $true
    }
    catch {
        Write-Error "Error connecting to Exchange online. Details: $($_.Exception.Message)"
        exit 1
    }

    Write-Host "Setting Outlook OOO message"
    try {
        Set-MailboxAutoReplyConfiguration `
            -Identity $Identity `
            -AutoReplyState $AutoReplyState `
            -StartTime $StartTime `
            -EndTime $EndTime `
            -InternalMessage $InternalMessageText `
            -ExternalMessage $ExternalMessageText
    }
    catch {
        Write-Error "Unable to set Outlook OOO message. Details: $($_.Exception.Message)"
        exit 1
    }

    Write-Host "Outlook OOO message set successfully."
    exit 0
}
else {
    Write-Warning "-Apply = `$false, OOO message will not be applied"
    exit 0
}