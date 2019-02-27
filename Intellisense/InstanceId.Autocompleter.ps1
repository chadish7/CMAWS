$ScriptBlock = {
  param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
  $InstanceList = (Get-EC2Instance).Instances | Where-Object -FilterScript {
    $PSItem.Tag.Key -match $wordToComplete -or
      $PSItem.Tag.Value -match $wordToComplete -or
      $PSItem.InstanceId -match $wordToComplete
  }
  $InstanceList.InstanceId
}

$Completer = @{
  CommandName = @(
        'Send-CMSSMPowerShell'
        'Set-CmEc2DnsName'
        'Set-CMEC2InstanceType'
        'Start-CmEc2Instance'
        'Stop-CmEc2InstanceWait'
  )
  ParameterName = 'InstanceId'
  ScriptBlock = $ScriptBlock
}
Register-ArgumentCompleter @Completer