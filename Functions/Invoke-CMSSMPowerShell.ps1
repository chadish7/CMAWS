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
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory               =$true,
            ValueFromPipeline              =$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]    $InstanceId,
        [string]      $Region,
        [Parameter(Mandatory               =$true)]
        [ScriptBlock] $Command
    )
    BEGIN {
        $ErrorActionPreference      = "Stop"
        If ($Region){
            $AllRegions    = (Get-AWSRegion).Region
            If ($AllRegions -notcontains $Region) {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS {
        foreach ($Instance in $InstanceId){
            $Parameters    = @{InstanceID  = $Instance}
            if ($Region)     {$Parameters.add('Region',$Region)}
            $CommandID     = (Send-SSMCommand @Parameters -DocumentName "AWS-RunPowerShellScript" -Parameter @{commands="$Command"}).CommandId
            While (!$false) {
                Start-Sleep -Seconds 1
                $SSMCommandStatus    = (Get-SSMCommand @Parameters -CommandId $CommandID).Status.Value
                if ($SSMCommandStatus -eq "Success") {
                    $SSMOutPut       = (Get-SSMCommandInvocationDetail @Parameters -CommandId $CommandID).StandardOutputContent
                    break
                } elseif ($SSMCommandStatus -eq "Failed") {
                    Write-Error "SSM Run Command to Failed"
                    break
                }
            }
            $OutputProperties = @{
                Output        = $SSMOutPut
                InstanceID    = $Instance
            }
            $OutputObject     = New-Object -TypeName PSObject -Property $OutputProperties
            Write-Output      $OutputObject
        }
    }
    END{}
}
