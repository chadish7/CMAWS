Function Invoke-CMSSMPowerShell        {
<#
.Synopsis
    Sends PowerShell Commands to a AWS EC2 SSM Managed Instance and displays results.
.DESCRIPTION
    Sends PowerShell Commands to a SSM Managed Instance and waits for the command to finish then brings back the output from that command to the console

.NOTES   
    Name:        Send-SSMPowerShellCommand
    Author:      Chad Miles
    DateUpdated: 2017-05-06
    Version:     1.0.1

.EXAMPLE
   C:\> $SSMCommands = {Get-Service Bits}
   C:\> Send-CMSSMPowerShell  -InstanceID i-abcdef1234567890 -Command $SSMCommands | Format-List
   
   InstanceID : i-abcdef1234567890
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...
   
.EXAMPLE
   C:\> $SSMCommands = {Get-Service Bits}
   C:\> Send-CMSSMPowerShell -InstanceID i-abcdef1234567890,i-1234567890abcdef -Region us-west-2 -Command $SSMCommands | Format-List
   
   InstanceID : i-abcdef1234567890
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...

   InstanceID : i-1234567890abcdef
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...
   .EXAMPLE
   C:\> $SSMCommands = {Get-Service Bits}
   C:\> Get-SSMInstanceInformation | Send-CMSSMPowerShell -Command $SSMCommands | Format-List
   
   InstanceID : {i-abcdef1234567890}
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...

   InstanceID : {i-1234567890abcdef}
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...


#>    
    [OutputType([String])]
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory               =$true,
            ValueFromPipeline              =$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]    $InstanceId,
        [ValidateScript({ @((Get-AWSRegion).Region) })]
        [string]      $Region,
        [string]      $ProfileName,
        [Parameter(Mandatory               =$true)]
        [ScriptBlock] $Command,
        [switch]      $NoWait
    )
    BEGIN {
        $ErrorActionPreference      = "Stop"
    }
    PROCESS {
        foreach ($Instance in $InstanceId){
            $Parameters    = @{InstanceId  = $Instance}
            if ($Region)      { $Parameters.Region      = $Region }
            if ($ProfileName) { $Parameters.ProfileName = $ProfileName }
            $SentCommand     = Send-SSMCommand @Parameters -DocumentName "AWS-RunPowerShellScript" -Parameter @{commands="$Command"}
            if (!$NoWait) {
                While (!$false) {
                    Start-Sleep -Seconds 1
                    $SSMCommandStatus    = (Get-SSMCommand @Parameters -CommandId $SentCommand.CommandId).Status.Value
                    if ($SSMCommandStatus -eq "Success") {
                        $SSMOutPut       = (Get-SSMCommandInvocationDetail @Parameters -CommandId $SentCommand.CommandId).StandardOutputContent
                        break
                    } elseif ($SSMCommandStatus -eq "Failed") {
                        Write-Error "SSM Run Command to Failed"
                        break
                    }
                }
                $OutputProperties = @{
                    Output        = $SSMOutPut
                    InstanceId    = $Instance
                }
                $OutputObject     = New-Object -TypeName PSObject -Property $OutputProperties
                Write-Output      $OutputObject
            } else {
                $SentCommand
            }
        } 
    }
    END{}
}
