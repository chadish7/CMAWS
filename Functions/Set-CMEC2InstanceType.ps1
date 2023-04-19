Function Set-CMEC2InstanceType       {
<#
.Synopsis
    Changes an EC2 instance type leaving it in the same state
.DESCRIPTION
    Changes the EC2 instance type of a running instance by shutting it down, changing the instance type and starting it again in one cmdlet or leaves it stopped if it was stopped.

.NOTES   
    Name:        Set-CMEC2InstanceType 
    Author:      Chad Miles
    DateUpdated: 2017-05-06
    Version:     1.0.0

.EXAMPLE
    C:\> Set-CMEC2InstanceType -InstanceID i-1234567890abcdef -InstanceType m4.large
    
    Shutting down Instance i-1234567890abcdef
    ........

    InstanceID          Status              InstanceType
    ----------          ------              ------------
    i-1234567890abcdef  running             m4.large

    In this example one instance was specified for changing running and was stopped, changed and started again.
    
.EXAMPLE
    C:\> (Get-EC2instances).instances | Where {$_.InstanceType -eq "t2.large"} | Set-CMEC2InstanceType -InstanceType m4.large

    Shutting down Instance i-1234567890fedcba
    ........

    InstanceID          Status              InstanceType
    ----------          ------              ------------
    i-1234567890fedcba  running             m4.large
    i-1234567890abcdef  stopped             m4.large

    In this example all the instances that were of instance type t2.large where changed to m4.large, of which there were two. However, one of the instances was in a stopped state and the other was running and they were both left in their respective states.
    
    #>    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory                = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]] $InstanceId,
        [Parameter(ValueFromPipeline        = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateScript({@((Get-AWSRegion).Region)})]
        [string]   $Region,
        [string]   $ProfileName,
        [Parameter(Mandatory=$true)]
        [ValidateScript({(Get-CmEc2InstanceTypes)})]
        [Alias("Type")] 
        [String]   $InstanceType,
        [string]   $DomainName
    )
    <#DynamicParam 
    {
        $Names                = Get-CmEc2InstanceTypes
        $ParameterName        = 'InstanceType'
        $ParamDictionary      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $ParamAttrib          = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory= 1
        $AttribColl           = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($Names)))
        $RuntimeParam         = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttribColl)
        $RuntimeParamDic      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RuntimeParamDic.Add($ParameterName,  $RuntimeParam)

        return  $RuntimeParamDic
    }#>
    BEGIN 
    {
        $InstanceType               = $PSBoundParameters.InstanceType
        $ErrorActionPreference      = "Stop"
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceId){
            $Parameters         = @{InstanceId  = $Instance}
            if ($Region)          { $Parameters.Region      = $Region }
            if ($ProfileName)     { $Parameters.ProfileName = $ProfileName }
            $InstanceStartInfo  = (Get-EC2Instance @Parameters).Instances
            $InstanceStartStatus= $InstanceStartInfo.State.Name.Value
            $InstanceStatus     = $InstanceStartStatus
            $InstanceStartType  = $InstanceStartInfo.InstanceType.Value
            If ($InstanceStartType -eq $InstanceType) {
                Write-Warning "Instance $Instance is already of instance type $InstanceType, skipping"
            } else {
                if ($InstanceStatus -ne "stopped") {Stop-CMEC2InstanceWait -InstanceId $Instance -Region $Region -NoCheck}
                Write-Verbose "Editing Instance Type"
                Edit-EC2InstanceAttribute @Parameters -InstanceType $InstanceType
                if ($InstanceStartStatus -eq "running") 
                {
                    Write-Verbose "Starting Instance"
                    if ($DomainName)
                    {
                        $StartInstance  = Start-CMInstance @Parameters -DomainName $DomainName
                        $InstanceStatus = $StartInstance.CurrentState
                        $Hostname       = $StartInstance.Hostname
                    }
                    else {
                        $StartInstance = Start-EC2Instance @Parameters
                        $InstanceStatus = $StartInstance.CurrentState.Name.Value
                    }
                }
                $OutputProperties = @{
                    InstanceID    = $Instance
                    Status        = $InstanceStatus
                    InstanceType  = $InstanceType
                }
                if ($HostName) {
                    $OutputProperties.Add('Hostname', $HostName)
                }
                [PSCustomObject]$OutputProperties
            }
        }
    }
    END{}
}
