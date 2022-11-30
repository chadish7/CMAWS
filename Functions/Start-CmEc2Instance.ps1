Function Start-CmEc2Instance         {
    [CmdletBinding()]
    [Alias('Start-CmInstance')]
    Param (
        [Parameter(
            Mandatory                       = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]  $InstanceId,
        [string]    $DomainName,
        [ValidateScript( { @((Get-AWSRegion).Region) })]
        [string]    $Region,
        [string]    $ProfileName
    )
    BEGIN 
    {
        $ErrorActionPreference      = "Stop"
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceID)
        {
            $Parameters = @{ InstanceId  = $Instance }
            if ($Region)         { $Parameters.Region      = $Region }
            if ($ProfileName)    { $Parameters.ProfileName = $ProfileName }
            $StartingInstance = Start-EC2Instance @Parameters
            If ($DomainName) {$SetDns = Set-CmEc2DnsName @Parameters -DomainName $DomainName}
            $ObjProperties    = @{
                InstanceId    = $Instance
                PreviousState = $StartingInstance.PreviousState.Name.Value              
            }
            If ($SetDns) {
                $ObjProperties.Add('HostName',    $SetDns.HostName)
                $ObjProperties.Add('CurrentState',$SetDns.CurrentState)
            } else {
                $ObjProperties.Add('CurrentState',$StartingInstance.CurrentState.Name.Value)
            }
            New-Object -TypeName PsObject -Property $ObjProperties
        }
    }
    END {}
}
