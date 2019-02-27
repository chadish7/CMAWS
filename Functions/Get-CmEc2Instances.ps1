Function Get-CmEc2Instances          {
    [Cmdletbinding()]
    Param (
        [string[]]$Region
    )
    $ErrorActionPreference = "Stop"
    $AllRegions    = (Get-AWSRegion).Region
    If (!$Region){
        $Region = $AllRegions
        Write-Warning "Getting instances for all regions, May take some time"
    } 
    Foreach ($Reg in $Region) {
        If ($AllRegions -notcontains $Reg) {Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"}
        $Instances = (Get-EC2Instance -Region $Reg).RunningInstance 
        Foreach ($Instance in $Instances) {  
            $Properties    = @{
                Name            = $Instance.Tags | Where-Object {$_.Key -eq "Name"} | Select -ExpandProperty Value
                State           = $Instance.State.Name
                InstanceType    = $Instance.InstanceType
                InstanceId      = $Instance.InstanceId
                AZ              = $Instance.Placement.AvailabilityZone
                LaunchTime      = $Instance.LaunchTime
                PublicIpAddress = $Instance.PublicIpAddress
            }
            $InstanceObject = New-Object PSObject -Property $Properties
            Write-Output $InstanceObject
        }
    }
    Write-Output $InstancesList
}
