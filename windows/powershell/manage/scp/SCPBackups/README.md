# SCP Backups

Script to make SCP operations a little easier. Copy the [example definitions file](./example.backup_definitions.json) to `backup_definitions.json`, create some operations, and run `./Start-SCPBackups.ps1 -DefinitionFile backup_definitions.json`.

Useful if you have a cron job creating backups, for example, that you want to synchronize to your localhost. This can be a scheduled task.

## Scheduled Task

Open the Task Scheduler and create a new task. Set a trigger, and in Actions, use "Start a Program."

* In the "Program.script" field, paste this: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
* In the "Add arguments (optional)" field, paste this: `-File "Start-SCPBackups.ps1" -DefinitionFile "backup_definitions.json"`
* In the "Start in (optional)" field, type the full path to the directory where [`Start-SCPBackups.ps1`](./Start-SCPBackups.ps1) and your [`backup_definitions.json`](./example.backup_definitions.json) file are.
