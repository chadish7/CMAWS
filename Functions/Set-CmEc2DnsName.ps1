Function Set-CmEc2DnsName            {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [string[]]  $InstanceId,
        [Parameter(Mandatory=$true)]
        [string]    $DomainName,
        [string]    $Region,
        [string]    $InstanceName
    )
    BEGIN 
    {
        $ErrorActionPreference      = "Stop"
        If ($Region)
        {
            $AllRegions = (Get-AWSRegion).Region
            $AllRegions += "af-south-1"
            If ($AllRegions -notcontains $Region) 
            {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceID)       
        {
            $Parameters       = @{InstanceID  = $Instance}
            If ($Region)        {$Parameters.add('Region',$Region)}
            $RunningInstance  = (Get-EC2Instance @Parameters).Instances
            if (!$RunningInstance) {
                Start-Sleep -Seconds 1
                $RunningInstance  = (Get-EC2Instance @Parameters).Instances
            }
            $CurrentState     = $RunningInstance.State.Name.Value
            if ($CurrentState -like "stop*" -or $CurrentState -like "term*"-or $CurrentState -like "shut*" -or !$CurrentState){
                Write-Error "Instance $Instance is not running. Please start it or specify another instance"
            }
            If ((Get-Ec2Subnet -SubnetId $RunningInstance.SubnetId -Region $Region).MapPublicIpOnLaunch -eq $true -and !$RunningInstance.PublicIpAddress) {
                $Counter          = 1
                While ($CurrentState -ne "running" -and !$RunningInstance.PublicIpAddress) {
                    Start-Sleep -Seconds 1
                    $Counter++
                    $RunningInstance  = (Get-EC2Instance @Parameters).Instances
                    $CurrentState     = $RunningInstance.State.Name.Value
                    if ($Counter -ge 30)
                    {
                        Write-Error "Instance $Instance took too long to start, aborting. WARNING Instance may still start and incur charges."
                    }
                }
            }
            If ($InstanceName) {$HostName  = $InstanceName+"."+$DomainName}
            Else {
                $InstanceName          = $RunningInstance.Tags | Where-Object {$_.Key -eq "Name"} | Select -ExpandProperty Value
            
                If (!$InstanceName) {
                    Write-Error "No Name Tag on instance $Instance, can't apply DNS Name."
                    $HostName     = $RunningInstance.PublicDnsName
                }  Else {
                    $HostName  = $InstanceName+"."+$DomainName
                }
            }
            
            If ($RunningInstance.PublicIpAddress) {
                Set-R53Record -Domain $DomainName -Type A -Name $InstanceName -Value $RunningInstance.PublicIpAddress -TTL 30 | Out-Null
            } Else {
                Set-R53Record -Domain $DomainName -Type A -Name $InstanceName -Value $RunningInstance.PrivateIpAddress -TTL 30 | Out-Null
            }
            $ObjProperties = @{
                InstanceID   = $Instance
                HostName     = $HostName
                CurrentState = $CurrentState
            }
            New-Object -TypeName PsObject -Property $ObjProperties
        }
    }
    END{}
}
