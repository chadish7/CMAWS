Function New-CmEasyPassword          {
    <#
    .Synopsis
       See New-CMPassword Help

       Alais for executing New-CMPassword -Easy -Count 1
    #>
    [Alias('npe')]
    Param(
        [int]      $Count = 1,
        [Switch]   $ClipOnly
    )
    if ($ClipOnly -eq $true) {
        New-CMPassword -Easy -Count $Count -ClipOnly
    } else {
        New-CMPassword -Easy -Count $Count
    }
}
