<#
    .SYNOPSIS
    Apply my default privacy & security policy to this machine.

    .DESCRIPTION
    Disables services and changes default configuration based on my preferences. The script turns off
    privacy nightmares like Recall, Copilot, data collection, and advertising ID.
#>
[CmdletBinding()]

##################
# Registry paths #
##################

$script:CopilotRegistryPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot",
    "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
)
$script:RecallRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
$script:DataCollectionRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
$script:AdvertisingRegistryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
$script:CloudContentRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
$script:FeedbackRegistryPath = "HKCU:\Software\Microsoft\Siuf\Rules"
$script:DiagnosticServices = @(
    "DiagTrack",
    "dmwappushservice"
)
$script:WidgetsRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
$script:EdgeRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$script:WindowsLocationServicesRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
$script:InputPersonalizationRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization"
$script:AppPrivacyRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
$script:TextInputRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TextInput"
$script:InputPersonalizationUserRegistryPath = "HKCU:\Software\Microsoft\InputPersonalization"
$script:InputPersonalizationPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization"
$script:ErrorReportingRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
$script:PCHealthErrorReportingRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting"
$script:DataCollectionRegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"

function Disable-DefenderRealtimeMonitoring() {
    <#
        .SYNOPSIS
        Disable Windows Defender realtime monitoring
    #>
    Write-Host "  [-] Disabling Windows Defender Real-Time monitoring" -ForegroundColor green
    PowerShell Set-MpPreference -DisableRealtimeMonitoring 1
}

function Disable-Copilot() {
    <#
        .SYNOPSIS
        Disable Windows Copilot
    #>
    [CmdletBinding()]
    param(
        $paths = $script:CopilotRegistryPaths
    )

    Write-Host "  [-] Disable Copilot"
    foreach ($path in $paths) {
        New-Item -Path $path -Force | Out-Null

        New-ItemProperty `
            -Path $path `
            -Name "TurnOffWindowsCopilot" `
            -PropertyType DWORD `
            -Value 1 `
            -Force | Out-Null
    }
}

function Disable-WindowsRecall() {
    <#
        .SYNOPSIS
        Disable Windows Recall
    #>
    [CmdletBinding()]
    param(
        $recallPath = $script:RecallRegistryPath
    )

    New-Item -Path $recallPath -Force | Out-Null

    $recallSettings = @{
        "DisableAIDataAnalysis" = 1
        "AllowRecallEnablement" = 0
        "DisableRecall"         = 1
    }

    Write-Host "  [-] Disable Windows Recall"
    foreach ($item in $recallSettings.GetEnumerator()) {
        New-ItemProperty `
            -Path $recallPath `
            -Name $item.Key `
            -PropertyType DWORD `
            -Value $item.Value `
            -Force | Out-Null
    }
}

function Enable-DefenderControlledFolderAccess() {
    <#
        .SYNOPSIS
        Enable controlled folder access
    #>
    Write-Host "  [+] Enable Defender Controlled Folder Access"

    Set-MpPreference -EnableControlledFolderAccess Enabled
}

function Disable-SMBv1() {
    <#
        .SYNOPSIS
        Disable insecure SMBv1
    #>
    Write-Host "  [-] Disable SMBv1"

    Disable-WindowsOptionalFeature `
        -Online `
        -FeatureName SMB1Protocol `
        -NoRestart `
        -ErrorAction SilentlyContinue
}

function Disable-AutoRun() {
    <#
        .SYNOPSIS
        Disable auto-run/auto-play
    #>
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable AutoRun"

    New-ItemProperty `
        -Path $path `
        -Name "NoAutorun" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

function Disable-WindowsLocation() {
    <#
        .SYNOPSIS
        Disable Windows Location services
    #>
    [CmdletBinding()]
    param(
        $path = $script:WindowsLocationServicesRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable Windows location services"

    New-ItemProperty `
        -Path $path `
        -Name "DisableLocation" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

function Set-DiagnosticDataPolicy() {
    <#
        .SYNOPSIS
        Set the Windows diagnostic data collection level.
    #>
    [CmdletBinding()]
    param(
        $dataCollection = $script:DataCollectionRegistryPath
    )

    New-Item -Path $dataCollection -Force | Out-Null

    Write-Host "  [-] Set Windows diagnostic data policy"

    New-ItemProperty `
        -Path $dataCollection `
        -Name "AllowTelemetry" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}

function Disable-AppDiagnosticInfoAccess() {
    <#
        .SYNOPSIS
        Prevent Windows apps from accessing diagnostic information about other apps.
    #>
    [CmdletBinding()]
    param(
        $path = $script:AppPrivacyRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable app access to diagnostic information"

    New-ItemProperty `
        -Path $path `
        -Name "LetAppsGetDiagnosticInfo" `
        -PropertyType DWORD `
        -Value 2 `
        -Force | Out-Null
}

function Disable-InkingAndTypingDataCollection() {
    <#
        .SYNOPSIS
        Disable collection of inking and typing data used to improve language recognition.
    #>
    [CmdletBinding()]
    param(
        $path = $script:TextInputRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable inking and typing data collection"

    New-ItemProperty `
        -Path $path `
        -Name "AllowLinguisticDataCollection" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}

function Disable-HandwritingPersonalization() {
    <#
        .SYNOPSIS
        Disable automatic handwriting personalization and learning.
    #>
    [CmdletBinding()]
    param(
        $path = $script:InputPersonalizationPolicyPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable handwriting personalization"

    New-ItemProperty `
        -Path $path `
        -Name "ImplicitDataCollectionOff_2" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

function Disable-InputPersonalizationDataCollection() {
    <#
        .SYNOPSIS
        Disable implicit text and ink collection used for input personalization.
    #>
    [CmdletBinding()]
    param(
        $path = $script:InputPersonalizationUserRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable input personalization data collection"

    New-ItemProperty `
        -Path $path `
        -Name "RestrictImplicitTextCollection" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null

    New-ItemProperty `
        -Path $path `
        -Name "RestrictImplicitInkCollection" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

function Disable-AdvertisingId() {
    <#
        .SYNOPSIS
        Disable advertising ID
    #>
    [CmdletBinding()]
    param(
        $advertising = $script:AdvertisingRegistryPath
    )

    New-Item -Path $advertising -Force | Out-Null

    Write-Host "  [-] Disable Advertising ID"
    New-ItemProperty `
        -Path $advertising `
        -Name "Enabled" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}

function Disable-TailoredExperiences() {
    <#
        .SYNOPSIS
        Disable tailored experiences
    #>
    [CmdletBinding()]
    param(
        $cloudContent = $script:CloudContentRegistryPath
    )
    
    New-Item -Path $cloudContent -Force | Out-Null

    $cloudSettings = @{
        "DisableWindowsConsumerFeatures"               = 1
        "DisableSoftLanding"                           = 1
        "DisableTailoredExperiencesWithDiagnosticData" = 1
        "DisableConsumerAccountStateContent"           = 1
    }

    Write-Host "  [-] Disable tailored experiences"
    foreach ($item in $cloudSettings.GetEnumerator()) {
        New-ItemProperty `
            -Path $cloudContent `
            -Name $item.Key `
            -PropertyType DWORD `
            -Value $item.Value `
            -Force | Out-Null
    }
}

function Disable-FeedbackPrompts() {
    <#
        .SYNOPSIS
        Disable prompts for user feedback
    #>
    [CmdletBinding()]
    param(
        $feedback = $script:FeedbackRegistryPath
    )

    New-Item -Path $feedback -Force | Out-Null

    Write-Host "  [-] Disable feedback prompts"
    New-ItemProperty `
        -Path $feedback `
        -Name "NumberOfSIUFInPeriod" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}


function Disable-DiagnosticServices() {
    <#
        .SYNOPSIS
        Disable diagnostics services
    #>
    [CmdletBinding()]
    param(
        $services = $script:DiagnosticServices
    )
    
    Write-Host "  [-] Disable diagnostics services that collect sensitive data"
    foreach ($service in $services) {
        $svc = Get-Service $service -ErrorAction SilentlyContinue

        if ($svc) {
            Stop-Service $service -Force -ErrorAction SilentlyContinue
            Set-Service $service -StartupType Disabled
        }
    }
}

function Disable-CopilotAppPackage() {
    <#
        .SYNOPSIS
        Disable Copilot App package
    #>
    Write-Host "  [-] Disable Copilot app package"

    Get-AppxPackage -AllUsers "*Microsoft.Copilot*" |
    Remove-AppxPackage `
        -ErrorAction SilentlyContinue
}

function Disable-Widgets() {
    <#
        .SYNOPSIS
        Disable Widgets
    #>
    [CmdletBinding()]
    Param(
        $widgets = $script:WidgetsRegistryPath
    )

    New-Item -Path $widgets -Force | Out-Null

    Write-Host "  [-] Disable widgets"
    New-ItemProperty `
        -Path $widgets `
        -Name "AllowNewsAndInterests" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}

function Disable-InputPersonalization() {
    <#
        .SYNOPSIS
        Disable online speech recognition
    #>
    [CmdletBinding()]
    param(
        $path = $script:InputPersonalizationRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable online speech recognition"

    New-ItemProperty `
        -Path $path `
        -Name "AllowInputPersonalization" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}

function Disable-WindowsErrorReporting() {
    <#
        .SYNOPSIS
        Disable Windows Error Reporting and prevent additional error data from being sent.
    #>
    [CmdletBinding()]
    param(
        $path = $script:ErrorReportingRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable Windows Error Reporting"

    New-ItemProperty `
        -Path $path `
        -Name "Disabled" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null

    New-ItemProperty `
        -Path $path `
        -Name "DontSendAdditionalData" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

function Disable-PCHealthErrorReporting() {
    <#
        .SYNOPSIS
        Disable Windows error reporting through the PC Health policy.
    #>
    [CmdletBinding()]
    param(
        $path = $script:PCHealthErrorReportingRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Disable PC Health error reporting"

    New-ItemProperty `
        -Path $path `
        -Name "DoReport" `
        -PropertyType DWORD `
        -Value 0 `
        -Force | Out-Null
}

function Limit-DiagnosticDataCollection() {
    <#
        .SYNOPSIS
        Prevent Windows from sending diagnostic logs and limit diagnostic dump collection.
    #>
    [CmdletBinding()]
    param(
        $path = $script:DataCollectionRegistryPath
    )

    New-Item -Path $path -Force | Out-Null

    Write-Host "  [-] Limit diagnostic logs and dumps"

    New-ItemProperty `
        -Path $path `
        -Name "LimitDiagnosticLogCollection" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null

    New-ItemProperty `
        -Path $path `
        -Name "LimitDumpCollection" `
        -PropertyType DWORD `
        -Value 1 `
        -Force | Out-Null
}

function Disable-EdgePrivacyFeatures() {
    <#
        .SYNOPSIS
        Disable Microsoft Edge personalization, shopping, rewards, background activity, and suggestion features.
    #>
    [CmdletBinding()]
    param(
        $edge = $script:EdgeRegistryPath
    )

    New-Item -Path $edge -Force | Out-Null

    $edgeSettings = @{
        ## Privacy/telemetry
        "PersonalizationReportingEnabled" = 0
        "MetricsReportingEnabled"         = 0
        "SendSiteInfoToImproveServices"   = 0

        ## Personalized advertising
        "AdsSettingForIntrusiveAdsSites"  = 0

        ## Shopping
        "EdgeShoppingAssistantEnabled"    = 0

        ## Microsoft Rewards
        "ShowMicrosoftRewards"            = 0

        ## Background operation
        "BackgroundModeEnabled"           = 0

        ## First-run experience
        "FirstRunExperienceEnabled"       = 0

        ## Search suggestions
        "SearchSuggestEnabled"            = 0

        ## Browser import prompts
        "ImportOnEachLaunch"              = 0
        "AutoImportAtFirstRun"            = 0

        ## Password saving
        "PasswordManagerEnabled"          = 0
        "OfferToSavePasswordsEnabled"     = 0
    }

    Write-Host "  [-] Disable Edge privacy and personalization features"

    foreach ($item in $edgeSettings.GetEnumerator()) {
        New-ItemProperty `
            -Path $edge `
            -Name $item.Key `
            -PropertyType DWORD `
            -Value $item.Value `
            -Force | Out-Null
    }
}

# +-------------------------------------------+ #

########
# Main #
########

Write-Host "`n[ Applying Windows 11 privacy policies ]"

Disable-Copilot
Disable-WindowsRecall

Set-DiagnosticDataPolicy
Limit-DiagnosticDataCollection
Disable-AppDiagnosticInfoAccess

Disable-AdvertisingId
Disable-TailoredExperiences
Disable-FeedbackPrompts

Disable-InkingAndTypingDataCollection
Disable-HandwritingPersonalization
Disable-InputPersonalizationDataCollection

Disable-WindowsLocation
Disable-OnlineSpeechRecognition

Disable-DiagnosticServices
Disable-WindowsErrorReporting
Disable-PCHealthErrorReporting

Disable-CopilotAppPackage
Disable-Widgets

Disable-SMBv1
Disable-AutoRun

Disable-EdgePrivacyFeatures

Disable-DefenderRealtimeMonitoring

Write-Host ""
Write-Host "Privacy settings applied."
Write-Host "Restart Windows to apply all changes."
