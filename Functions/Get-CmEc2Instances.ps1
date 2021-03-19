Function Get-CmEc2Instances {
    [Cmdletbinding()]
    Param (
        [string[]]$Regions
    )
    $ErrorActionPreference = "Stop"
    $AllRegions = (Get-AWSRegion).Region
    If (!$Regions) {
        $Regions = $AllRegions
        Write-Warning "Getting instances for all regions, May take some time"
    } 
    Foreach ($Region in $Regions) {
        If ($AllRegions -notcontains $Region) { Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions" }
        $Instances = (Get-EC2Instance -Region $Region).Instances
        Foreach ($Instance in $Instances) {  
            $Properties = @{
                Name            = $Instance.Tags | Where-Object { $_.Key -eq "Name" } | Select-Object -ExpandProperty Value
                State           = $Instance.State.Name
                InstanceType    = $Instance.InstanceType
                InstanceId      = $Instance.InstanceId
                AZ              = $Instance.Placement.AvailabilityZone
                RunningTime     = 
                If ($Instance.State.Name -eq "Running") {
                    $ts = New-Timespan -Start $Instance.LaunchTime
                    ('{0} {1:D2}:{2:D2}:{3:D2}' -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds).TrimStart("0 :")
                } Else {}
                PublicIpAddress = $Instance.PublicIpAddress
            }
            $InstanceObject = New-Object PSObject -Property $Properties
            Write-Output $InstanceObject
        }
    }
    Write-Output $InstancesList
}
