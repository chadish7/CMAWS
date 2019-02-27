$ScriptBlock = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    $Global:Instances.Name -match $wordToComplete
}
$Completer = @{
    CommandName   = @('Select-Instance')
    ParameterName = 'InstanceNames'
    ScriptBlock   = $ScriptBlock
}
Register-ArgumentCompleter @Completer