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
        [ValidateScript( { @((Get-AWSRegion).Region) })]
        [string]    $Region
    )
    BEGIN 
    {
        $ErrorActionPreference      = "Stop"
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
