Function Get-AWSCurrentSpend {
    [OutputType([PSCustomObject])]
    param (
        # The AWS CLI or PowerShell tools profile to use for Authentications
        [String] $ProfileName
    
    )
    $Param = @{}
    If ($ProfileName)   {$Param['ProfileName'] = $ProfileName}
    $CurrentPeriod = @{
        Start = Get-Date -UFormat "%Y-%m-%d" -Day 1 
        End   = Get-Date -UFormat "%Y-%m-%d"
    }
    $LastMonth = @{
        Start = (Get-Date -Day 1).AddMonths(-1) | Get-Date -UFormat "%Y-%m-%d"
        End   = Get-Date -UFormat "%Y-%m-%d" -Day 1
    }
    $FCPeriod = @{
        Start = (Get-Date).AddDays(1) | Get-Date -UFormat "%Y-%m-%d"
        End   = (Get-Date -Day 1 -Month (Get-Date).AddMonths(1).Month).AddDays(-1) | Get-Date -UFormat "%Y-%m-%d"
    }
    $Output = @{
        Date           = $CurrentPeriod.End
        LastMonthSpend = [Math]::Round((Get-CECostAndUsage @Param -TimePeriod $LastMonth     -Granularity Monthly -Metric UNBLENDED_COST).ResultsByTime.Total.Values.Amount,2)
        Spend          = [Math]::Round((Get-CECostAndUsage @Param -TimePeriod $CurrentPeriod -Granularity Monthly -Metric UNBLENDED_COST).ResultsByTime.Total.Values.Amount,2)
    }
    Try { 
        $Forecast = [Math]::Round(
            (Get-CECostForecast @Param -TimePeriod $FCPeriod -Granularity Monthly -Metric UNBLENDED_COST).Total.Amount,
            2
        )
        
    } Catch { 
        $Forecast = [Math]::Round(
            ($Output.Spend/(Get-Date).Day * (Get-Date -Day (Get-Date -Month (Get-Date).AddMonths(1).Month -Day 1).AddDays(-1).Day).Day),
            2
        )
    }
    $Output.Add(
        "Forecast",
        $Forecast
    )
    [PSCustomObject]$Output
} 