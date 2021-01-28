Function Stop-CmEc2InstanceWait      {
<#
.Synopsis
    Stops an instance and waits for stop
.DESCRIPTION
    Stops an EC2 instance and waits for the instance to enter the stopped state before continueing

.NOTES   
    Name:        Stop-CMEC2InstanceWait
    Author:      Chad Miles
    DateUpdated: 2017-08-16
    Version:     1.0.0

.EXAMPLE
   PS C:\> Stop-CMEC2InstanceWait -InstanceId 1234567890abcdef
   Stopping Instance 1234567890abcdef ........

   This will stop the instance 1234567890abcdef in the default region.
.EXAMPLE
   PS C:\> Stop-CMEC2InstanceWait -InstanceId 1234567890abcdef, 0987654321fedcba
   Stopping Instance 1234567890abcdef ........
   Stopping Instance 0987654321fedcba ........

   This will stop the instances specified in the default region.
.EXAMPLE
   PS C:\> (Get-EC2Instance).Instances | Stop-CMEC2InstanceWait
   Stopping Instance 1234567890abcdef ........
   Stopping Instance 0987654321fedcba ........

   This will stop the instances piped in from the Get-EC2Intances cmdlet in the default region.
#>    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory                = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]] $InstanceId,
        [string]   $Region,
        #If set, doesn't check if Instance is running and assumes it is, and tries to stop and then start it again afterwards.
        [switch]   $NoCheck
        
    )
    BEGIN {
        $ErrorActionPreference = "Stop"
        If ($Region){
            $AllRegions    = (Get-AWSRegion).Region
            $AllRegions += "af-south-1"
            If ($AllRegions -notcontains $Region) {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS {
        foreach ($Instance in $InstanceId){
            $Parameters         = @{InstanceID  = $Instance}
            If ($Region)          {$Parameters.add('Region',$Region)}
            If (!$NoCheck) {
                $InstanceStartInfo  = (Get-EC2Instance @Parameters).Instances
                $InstanceStatus     = $InstanceStartInfo.State.Name.Value
            } else {$InstanceStatus = "running"}
            If ($InstanceStatus -ne "stopped") {
                Write-Host "Stopping Instance $Instance" -NoNewline
                $StopInstance       = Stop-EC2Instance @Parameters
                While ($InstanceStatus -ne "stopped"){
                    Start-Sleep -Seconds 3
                    $InstanceStatus = (Get-EC2Instance @Parameters).Instances.State.Name.Value
                    Write-Host "." -NoNewline
                }
                Write-Host ""
            }
        }
    }
}
