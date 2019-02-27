$ScriptBlock = {
  param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
  (Get-CmEc2InstanceTypes) -match $wordToComplete
}

$Completer = @{
    CommandName = @(
        'Compare-CMEC2WindowsSpotPricingToOndemand'
        'Get-CmEc2InstanceTypes'
        'Get-Ec2WindowsOndemandPrice'
        'New-CmEC2Instance'
        'Set-CMEC2InstanceType'
    )
    ParameterName = 'InstanceType'
    ScriptBlock = $ScriptBlock
    }
Register-ArgumentCompleter @Completer