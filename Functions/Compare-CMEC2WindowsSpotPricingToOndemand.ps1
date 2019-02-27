Function Compare-CMEC2WindowsSpotPricingToOndemand {
    Param(
        [Parameter(Mandatory=$true)]
        [string[]] $InstanceType,
        [Parameter(Mandatory=$true)]
        [string[]] $Region   
    )

    foreach ($Reg in $Region){
        foreach ($Instance in $InstanceType){
            $Parameters          = @{
                Region           = $Reg
                InstanceType     = $Instance
            }

            $OndemandPrice       = Get-EC2WindowsOndemandPrice @Parameters
            $CurrentSpotPrice    = ((Get-EC2SpotPriceHistory   @Parameters -StartTime (Get-Date) -ProductDescription Windows).Price | Measure-Object -Minimum).Minimum
            $Savings             = (($OndemandPrice-$CurrentSpotPrice)/$OndemandPrice).ToString("P")
            $OutputProperties    = @{
                Region           = $Reg
                InstanceType     = $Instance
                OnDemandPrice    = $OndemandPrice
                CurrentSpotPrice = $CurrentSpotPrice
                Savings          = $Savings
            }
            $OutputObject        = New-Object -TypeName psobject -Property $OutputProperties
            Write-Output $OutputObject
        }
    }
}
