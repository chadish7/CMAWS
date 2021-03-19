Function New-CmEasyPassword          {
    <#
    .Synopsis
       See Get-Help New-CMPassword

       Alias for executing New-CMPassword -Easy -Count 1
    #>
    [Alias('npe')]
    Param(
        [int]      $Count = 1,
        [Switch]   $ClipOnly
    )
    New-CMPassword -Easy -Count $Count -ClipOnly:$ClipOnly
}