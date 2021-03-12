Function Get-AWSCurrentSpend {
    $CurrentPeriod = @{
        Start = Get-Date -UFormat "%Y-%m-%d" -Day 1 
        End   = Get-Date -UFormat "%Y-%m-%d"
    }
    $LastMonth = @{
        Start = Get-Date -UFormat "%Y-%m-%d" -Day 1 -Month (Get-Date).AddMonths(-1).Month
        End   = Get-Date -UFormat "%Y-%m-%d" -Day 1
    }
    $FCPeriod = @{
        Start = Get-Date -Day (Get-Date).AddDays(1).Day -UFormat "%Y-%m-%d"
        End   = Get-Date -Day (Get-Date -Month (Get-Date).AddMonths(1).Month -Day 1).AddDays(-1).Day -UFormat "%Y-%m-%d"
    }
    $Output = @{
        Date           = $CurrentPeriod.End
        LastMonthSpend = [Math]::Round((Get-CECostAndUsage -TimePeriod $LastMonth     -Granularity Monthly -Metric UNBLENDED_COST).ResultsByTime.Total.Values.Amount,2)
        Spend          = [Math]::Round((Get-CECostAndUsage -TimePeriod $CurrentPeriod -Granularity Monthly -Metric UNBLENDED_COST).ResultsByTime.Total.Values.Amount,2)
    }
    Try { 
        $Forecast = [Math]::Round(
            (Get-CECostForecast -TimePeriod $FCPeriod -Granularity Monthly -Metric UNBLENDED_COST).Total.Amount,
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