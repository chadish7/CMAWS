Function Stop-CMAllInstances         {
    Param ($Region)
    If (!$Region){
        $Region = (Get-AWSRegion).Region
    }
    foreach ($Reg in $Region) {
        $Instances = (Get-EC2Instance -Region $Reg).RunningInstance
        foreach ($Instance in $Instances)
        {
            $Tags          = ($Instances.tags).Key
            $InstanceState = ($Instances.State).Name
            if ($Tags -notcontains "Persistent" -and $InstanceState -ne "stopped")
            {
                $InstanceId = ($Instances).InstanceId
                Write-Output "Stopping $InstanceId"
                Stop-EC2Instance -InstanceId $InstanceId -Region $Reg | Out-Null
            }
        }
    }
}
