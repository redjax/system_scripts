# Visual Studio Code Backup

Script to create backup of VS Code extensions, keybinds, & settings.

## Usage

Run the script with an optional `-BackupDir` parameter. If no `-BackupDir` is provided, the default is `$env:USERPROFILE\VSCodeBackup`.

The script will create backups of VS Code's extensions, keybinds, & settings at the `-BackupDir` path.

### As a Scheduled Task

On Windows, you can create a scheduled backup task using the Task Scheduler. Create a new task and use the following for the action:

- Program/script: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Args: `-File "C:\path\to\backup_vscode.ps1" [-BackupDir "C:\path\to\vscode_backup"] [-Trim]`
  - `-BackupDir` and `-Trim` are optional
