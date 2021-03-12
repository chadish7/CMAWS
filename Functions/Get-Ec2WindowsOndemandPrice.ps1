Function Get-Ec2WindowsOndemandPrice {
    <#
.Synopsis
    Gets the hourly price of a Windows AWS EC2 instance type.
#>
    Param(
        #The Instance type you wish to change the instance to, e.g. m4.large. To see all instance types see https://aws.amazon.com/ec2/instance-types/
        [Parameter(Mandatory = $true)]
        [string] $InstanceType,
        [string] $Region = "us-east-1",
        [switch] $Monthly
    )
    $ErrorActionPreference = "Stop"
    $AllRegions = (Get-AWSRegion).Region
    If ($AllRegions -notcontains $Region) { Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions" }
    If (-not $Global:PricingObject) {
        $OnDemandPricing = Invoke-RestMethod -uri http://a0.awsstatic.com/pricing/1/ec2/mswin-od.min.js
        $IntroText = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright " + ((Get-Date).Year) + " Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $IntroText2 = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright " + ((Get-Date).AddDays(-90).Year) + " Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $OnDemandPricing = $OnDemandPricing.TrimStart($IntroText)
        $OnDemandPricing = $OnDemandPricing.TrimStart($IntroText2)
        $OnDemandPricing = $OnDemandPricing.TrimEnd(');')
        $Global:PricingObject = ($OnDemandPricing | ConvertFrom-Json).config.regions
    }
    $RegionPrices = $PricingObject | Where-Object { $_.region -eq $Region }
    $AllInstances = $RegionPrices.instancetypes.sizes
    $InstanceEntry = $AllInstances | Where-Object { $_.size -eq $InstanceType }
    if ($Monthly) { [math]::Round([float]$InstanceEntry.valuecolumns.prices.usd * 744, 2) }
    Else { $InstanceEntry.valuecolumns.prices.usd }
}