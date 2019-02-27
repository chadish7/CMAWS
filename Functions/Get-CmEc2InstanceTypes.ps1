Function Get-CmEc2InstanceTypes      {
    <#Param ($Region)
    if (-not $Region) {$Region  = "us-east-1"}
    If (-not $Global:PricingObject)
    {
        $OnDemandPricing       = Invoke-RestMethod -uri http://a0.awsstatic.com/pricing/1/ec2/mswin-od.min.js
        $IntroText             = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright "+((Get-Date).Year)+" Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $IntroText2            = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright "+((Get-Date).AddDays(-90).Year)+" Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $OnDemandPricing       = $OnDemandPricing.TrimStart($IntroText)
        $OnDemandPricing       = $OnDemandPricing.TrimStart($IntroText2)
        $OnDemandPricing       = $OnDemandPricing.TrimEnd(');')
        $Global:PricingObject  = ($OnDemandPricing | ConvertFrom-Json).config.regions
    }
    $RegionPrices          = $PricingObject | where {$_.region -eq $Region}
    $RegionPrices.instancetypes.sizes.size
    #>
    Import-Csv $PSScriptRoot\..\EC2Instances.csv | Select -ExpandProperty "API Name"
}