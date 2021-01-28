Function Start-CmEc2Instance         {
    [CmdletBinding()]
    [Alias('Start-CmInstance')]
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [string[]]  $InstanceId,
        [string]    $DomainName,
        [string]    $Region
    )
    BEGIN 
    {
        $ErrorActionPreference      = "Stop"
        If ($Region){
            $AllRegions = (Get-AWSRegion).Region
            $AllRegions += "af-south-1"
            If ($AllRegions -notcontains $Region) { 
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceID)
        {
            $Parameters       = @{InstanceID  = $Instance}
            if ($Region)        {$Parameters.add('Region',$Region)}
            $StartingInstance = Start-EC2Instance @Parameters
            If ($DomainName) {$SetDns = Set-CmEc2DnsName @Parameters -DomainName $DomainName}
            $ObjProperties    = @{
                InstanceID    = $Instance
                PreviousState = $StartingInstance.PreviousState.Name.Value              
            }
            If ($SetDns) 
            {
                $ObjProperties.Add('HostName',$SetDns.HostName)
                $ObjProperties.Add('CurrentState',$SetDns.CurrentState)
            }
            else 
            {
                $ObjProperties.Add('CurrentState',$StartingInstance.CurrentState.Name.Value)
            }
            New-Object -TypeName PsObject -Property $ObjProperties
        }
    }
    END {}
}
