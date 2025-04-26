# Disable Windows Recall

Don't trust Microsoft with your privacy? Good, you shouldn't. These scripts disable the Windows Recall "feature."

There are 2 scripts, try the Windows Feature removal script first, and if that fails, use the script that disables via registry. **NOTE**: Both of these scripts require an elevated session.

| Script | Description |
| ------ | ----------- |
| [`Disable-WindowsRecallFeature.ps1`](./Disable-WindowsRecallFeature.ps1) | This script disables Windows Recall by removing the feature via "Turn Windows Features On/Off". If your machine has not gotten the update with Recall, this script will fail and you can use the registry edit script. |
| [`Disable-RecallViaRegistry.ps1`](./Disable-RecallViaRegistry.ps1) | This script disables Windows Recall by creating or modifying a registry key value. This is similar to using a Group Policy. Microsoft likes to helpfully reset your registry edits occasionally, you might need to re-run this script after a Windows Update. |
