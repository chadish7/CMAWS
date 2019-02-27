#Requires -version 3.0
# This module file simply dot sources all .ps1 files in the Functions subfolder.
# This simplifies management of the modules functions.

# Sets the Script Path variable to the scripts invocation path.
$ScriptPath = Split-Path -Path $MyInvocation.MyCommand.Path

$Paths = @('Functions', 'Intellisense')
foreach ($Path in $Paths)
{
    try
    {
        $ItemPath = '{0}\{1}' -f $ScriptPath, $Path

        # Retrieve all .ps1 files in the Functions subfolder
        $Files = Get-ChildItem -Path $ItemPath -Name '*.ps1' -Attributes !D

        # Dot source all .ps1 file found
        foreach ($FunctionFile in $Files)
        {
            . "$($ItemPath)\$FunctionFile"
        }
    }
    catch
    {
        Write-Warning -Message ('{0}: {1}' -f $FunctionFile, $_.Exception.Message)
        Continue
    }
}
