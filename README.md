# Scripts #

Miscellaneous standalone scripts.

## Invoke-ChoiceMenu.ps1 ##

Invokes a Yes/No/Cancel choice menu to allow end users to easily run a script and verify the result.

Code to be executed should be placed in the try block of the first case (0) in the switch statement. If a user chooses "Yes" to the choice the code is executed. Choosing "No" will skip the choice, choosing "Cancel" will exit the script. Any exceptions raised by executed code will be caught by the choice option they were executed from and the user will have the option to continue with any remaining choices.

Invoke-ChoiceMenu works best when using the `Invoke-ChoiceMenu.bat` file to provide a file for the user to click on to launch the script ([credit](http://blog.danskingdom.com/allow-others-to-run-your-powershell-scripts-from-a-batch-file-they-will-love-you-for-it/)).

Under Windows 10 when running from a `.bat` file the font size properties of `cmd.exe` (which are a couple of points larger than `powershell.exe`) seem to be copied to the Powershell session, which results in it being larger than default.

### Example ###

`.\Invoke-ChoiceMenu.ps1 -WindowTitle 'My Title' -Transcript`

## Update-ExcelExternalRefs.ps1 ##

Modifies the path to external files referenced from an Excel Workbook. These would be linked spreadsheets which can be found under the "Data" > "Edit Links" option in the application.

For example, if files are migrated from a local folder to a remote folder (`C:\` to `P:\`) any linked spreadsheets will break if their path is also changed, and a prefix section of the path will need to be updated to the correct location. Excel must be installed on the machine the script is executed on.

### Example ###

`.\Update-ExcelExternalRefs.ps1 -SearchPath 'C:\Users\User1\Documents\' -Find 'C:\Users\User1\Documents\Accounts\' -Replace 'P:\Shared\Accounts\'`

## Get-MailboxDatabaseLogFile.ps1 ##

Gets the log files associated with an Exchange database. By default only the log files committed to the Exchange database are returned. These are log files that can be moved or deleted in a situation where free space on the volume hosting the database is running out. Exchange 2010 and greater is supported only.

Log files with a sequence number are matched using the ESE Utilites binary (`eseutil.exe`) included with Exchange, these are files with a prefix then 8 digits of hexadecimal (`E000000001A.log`). The active log file is not matched.

The correct way to purge log files is to run a backup, this ensures that a valid copy of the database exists and therefore log files older than the backup date are no longer needed to complete a restore. If log files after the last backup date are deleted, and database corruption occurs, then data since the last backup is lost. When log files are still available they can be replayed into a restored database to reduce the data loss.

### Example ###

`.\Get-MailboxDatabaseLogFile.ps1 -LogFolderPath 'D:\ExchangeDB1\' -LogFilePrefix 'E00'`

`Get-MailboxDatabase -Name ExchangeDB1 | . \Get-MailboxDatabaseLogFile.ps1 | Select-Object -Last 20 | Remove-Item`

`Get-MailboxDatabase -Name ExchangeDB1 | . \Get-MailboxDatabaseLogFile.ps1 | Move-Item -Destination "C:\CommitedLogs"`

## Test-DnsServerScavenging.ps1 ##

Runs a test scavenging event and returns DNS resource records that are candidates for removal and considered stale. There are two parts to DNS scavenging, the aging interval settings which are configured per zone, and the scavenging event or task that is typially configured on one DNS server only.

By default the aging settings of the DNS zone will be used (the default is 7 days for both no refresh and refresh). However a duration for the intervals can be chosen by passing a `[TimeSpan]` object to the `-NoRefreshInterval` and `-RefreshInterval` parameters.

Records that fall within either of the two intervals can be returned using the `-Type` parameter with the `NoRefresh` or `Refresh` keywords. The keyword `Stale` can be used to return records that fall outside both interval durations. This is the default behaviour.

For DNS resource record timestamps to be replicated aging must be enabled on the zone, if it is not enabled timestamp attributes will only be updated on the server that the client chose to report in to. This will usually be the primary DNS server for the site or subnet the client is a member of. The `-ComputerName` parameter can be used to choose which server to run the cmdlet against.

### Example ###

`./Test-DnsServerScavenging -ZoneName 'lan.example.com'`

`./Test-DnsServerScavenging -ZoneName 'lan.example.com' -Type Refresh -ComputerName 'lab-hq-dc1'`

`./Test-DnsServerScavenging -ZoneName 'lan.example.com' -NoRefreshInterval (New-TimeSpan -Days 3) -RefreshInterval (New-TimeSpan -Days 7)`

## PasswordNotifyTask.ps1 ##

Sends a customizable message to user accounts that are configured with an email address and a password that can expire. This is best used as a scheduled task and can be configured by editing variables in the script.

### Configuration ###

To run the script on a domain member server the `ActiveDirectory` PowerShell module is required, this can be installed with `Install-WindowsFeature RSAT-AD-PowerShell`.

The following variables are available for configuration in the script file. `AD_SERVER`, `NOTIFY_BEFORE`, `NOTIFY_GROUP`, `NOTIFY_OU`, `NOTIFY_NAME`, `EMAIL_TEST`, `EMAIL_SERVER`, `EMAIL_PORT`, `EMAIL_SSL`, `EMAIL_CREDENTIAL`, `EMAIL_FROM`, `EMAIL_SUBJECT`, `EMAIL_BODY`.

To log information and errors to the "Application" event log an event source named `PasswordNotifyTask` must be registered. This can be done with the follow command on the server running the script.

`New-EventLog -LogName 'Application' -Source 'PasswordNotifyTask'`

### Permissions ###

When running the script under a "Domain User" account the permissions below are required where appropriate.

The account must have read access to the objects in the `Password Settings Container` that define fine grained password policies. This can be done by applying `List contents`, `Read all properties` and `Read` permissions to the `Descendant msDS-PasswordSettings` and `Descendant msDS-PasswordSettingsContainer` object classes on the `Password Settings Container`.

If run on a Domain Controller with UAC enabled, objects required by the script may be filtered by UAC if an account without Domain Admin permissions is used. To avoid this issue the variable `AD_SERVER` can be configured in the script to run commands on a specified Domain Controller. A remote connection will not be subject to UAC filtering.

## Invoke-PingLog.ps1 ##

Tests and monitors network connectivity using ICMP echo packets. Behavior is similar to the Windows ping command and essentially wraps the `Win32_PingStatus` WMI class.

Failure and success responses can be filtered by a chosen threshold to aid monitoring of connections, and logging to a CSV format file is possible. Logs are not effected by filtering. 

If a domain name resolves to both an IPv4 and an IPv6 address then the IPv6 address will be preferred, this is a behaviour of the `Win32_PingStatus` class with no option to force either protocol.

### Example ###

`.\Invoke-Pinglog.ps1 8.8.8.8 -ResolveAddress -Count 4`

`.\Invoke-Pinglog.ps1 google.com -WriteType Failed -EnableLog -LogPath "C:\Users\Administrator\Documents"`
