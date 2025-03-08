# Outlook OOO

Powershell script to set your Outlook's Out of Office message.

## Usage

```powershell
Set-OutlookOOO.ps1 [[-Identity] <string>] [[-UPN] <string>] [[-AutoReplyState] <string>] [[-StartTime] <datetime>] [[-EndTime] <datetime>] [[-InternalMessageFile] <string>] [[-ExternalMessageFile] <string>] [[-Apply] <bool>] [<CommonParameters>]
```

Example:

```powershell
.\Set-OutlookOOO.ps1 -StartTime "2025-03-07 12:00 PM" -EndTime "2025-03-07 5:00 PM" -InternalMessageFile messages/internal/epi.txt -ExternalMessageFile messages/external/epi.txt -UPN myusername@mycompany.com
```
