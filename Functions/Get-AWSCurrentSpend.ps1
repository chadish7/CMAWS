Function Get-AWSCurrentSpend {
    $SpendPeriod = @{
        Start = Get-Date -UFormat "%Y-%m-%d" -Day 1 
        End   = Get-Date -UFormat "%Y-%m-%d"
    }
    $FCPeriod = @{
        Start = Get-Date -Day (Get-Date).AddDays(1).Day -UFormat "%Y-%m-%d"
        End   = Get-Date -Day (Get-Date -Month (Get-Date).AddMonths(1).Month -Day 1).AddDays(-1).Day -UFormat "%Y-%m-%d"
    }
    $Output = @{
        Date     = $SpendPeriod.End
        Spend    = [Math]::Round((Get-CECostAndUsage -TimePeriod $SpendPeriod -Granularity Monthly -Metric UNBLENDED_COST).ResultsByTime.Total.Values.Amount,2)
    }
    Try { 
        $Output.Add(
            "Forecast",
            [Math]::Round(
                (Get-CECostForecast -TimePeriod $FCPeriod -Granularity Monthly -Metric UNBLENDED_COST).Total.Amount,
                2
            )
        )
    } Catch { 
        $Output.Add(
            "Forecast",
            [Math]::Round(
                ($Output.Spend/(Get-Date).Day * (Get-Date -Day (Get-Date -Month (Get-Date).AddMonths(1).Month -Day 1).AddDays(-1).Day).Day),
                2
            )
        )
    }
    [PSCustomObject]$Output
} 