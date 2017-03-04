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

Log files with a sequence number are matched using the ESE Utilites binary (eseutil.exe) included with Exchange, these are files with a prefix then 8 digits of hexadecimal (E000000001A.log). The active log file is not matched.

The correct way to purge log files is to run a backup, this ensures that a valid copy of the database exists and therefore log files older than the backup date are no longer needed to complete a restore. If log files after the last backup date are deleted, and database corruption occurs, then data since the last backup is lost. When log files are still available they can be replayed into a restored database to reduce the data loss.

### Example ###

`.\Get-MailboxDatabaseLogFile.ps1 -LogFolderPath 'D:\ExchangeDB1\' -LogFilePrefix 'E00'`
`Get-MailboxDatabase -Name ExchangeDB1 | . \Get-MailboxDatabaseLogFile.ps1 | Select-Object -Last 20 | Remove-Item`
`Get-MailboxDatabase -Name ExchangeDB1 | . \Get-MailboxDatabaseLogFile.ps1 | Move-Item -Destination "C:\CommitedLogs"`