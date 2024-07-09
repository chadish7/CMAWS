Function Get-CmEc2Instances {
    [OutputType([PSCustomObject])]
    [Cmdletbinding()]
    Param (
        [ValidateScript( { @((Get-AWSRegion).Region) })]
        [string[]] $Regions,
        [string]   $ProfileName
    )
    $ErrorActionPreference = "Stop"
    $AllRegions = (Get-AWSRegion | Where-Object Region -notlike "*iso*").Region
    If (!$Regions) {
        $Regions = $AllRegions
        Write-Warning "Getting instances for all regions, May take some time"
    } 
    $Regions | ForEach-Object {
        $Region = $_
        $GeneralSplat = @{Region = $Region}
        if ($ProfileName) { $GeneralSplat.ProfileName = $ProfileName }
        If ($AllRegions -notcontains $Region) { Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions" }
        $Instances = (Get-EC2Instance @GeneralSplat).Instances
        Foreach ($Instance in $Instances) {  
            [PSCustomObject]@{
                Name             = $Instance.Tags | Where-Object { $_.Key -eq "Name" } | Select-Object -ExpandProperty Value
                State            = $Instance.State.Name
                InstanceType     = $Instance.InstanceType
                InstanceId       = $Instance.InstanceId
                AvailabilityZone = $Instance.Placement.AvailabilityZone
                RunningTime      = 
                    If ($Instance.State.Name -eq "Running") {
                        $ts = New-Timespan -Start $Instance.LaunchTime
                        ('{0} {1:D2}:{2:D2}:{3:D2}' -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds).TrimStart("0 :")
                    } Else {}
                PublicIpAddress = $Instance.PublicIpAddress
                Platform        = $Instance.Platform.Value 
            }
        }
    }
}
