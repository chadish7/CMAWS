$ScriptBlock = {
  param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
  (Get-AWSRegion).Region -match $wordToComplete
}

$Completer = @{
    CommandName = @(
        'Compare-CMEC2WindowsSpotPricingToOndemand'
        'Get-CmEc2ImageId'
        'Get-CmEc2Instances'
        'Get-CmEc2InstanceTypes'
        'Get-Ec2WindowsOndemandPrice'
        'New-CmEC2Instance'
        'Send-CMSSMPowerShell'
        'Set-CmEc2DnsName'
        'Set-CMEC2InstanceType'
        'Start-CmEc2Instance'
        'Stop-CMAllInstances'
        'Stop-CmEc2InstanceWait'
    )
    ParameterName = 'Region'
    ScriptBlock   = $ScriptBlock
    }
Register-ArgumentCompleter @Completer

