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

