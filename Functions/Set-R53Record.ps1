Function Set-R53Record               {
    <# 
        .SYNOPSIS 
            Made for easier interaction with Amazon Route 53 DNS service.
        .DESCRIPTION 
            Run the script in CREATE/UPDATE mode in order to add or modify DNS records in Amazon Route 53.
            Requires 4 parameters - Domain name and type, name and the value of DNS record.
        .NOTES 
            This script is based off the below, but it has been updated to better handle various scenarios, but credit where it's due:
            File name : Set-R53Record.ps1
            Author    : Sinisa Mikasinovic - six@mypowershell.space
            Date      : 02-Jan-17
            Script created as part of a learning tutorial at mypowershell.space.
            http://mypowershell.space/index.php/2017/01/02/amazon-route-53-records/
            All expected functionality may not be there, make sure you give it a test run first.
            Feel free to update/modify. I'd be interested in seeing it improved.
            This script example is provided "AS IS", without warranties or conditions of any kind, either expressed or implied.
            By using this script, you agree that only you are responsible for any resulting damages, losses, liabilities, costs or expenses.
        .LINK 
            http://mypowershell.space
        .EXAMPLE 
            Set-R53Record -Domain mypowershell.space -Type A -Name www -Value 1.2.3.4 -TTL 300
            Create an A record to point www.mypowershell.space to IP 1.2.3.4. TTL set to 5 minutes.
        .EXAMPLE 
            Set-R53Record -Domain mypowershell.space -Type A -Name mail -Value 1.2.3.4 -TTL 3600 -Comment "mail entry"
            Create an A record to point mail.mypowershell.space to IP 1.2.3.4. TTL set to 60 minutes and has an optional comment.
        .EXAMPLE 
            Set-R53Record -Domain mypowershell.space -Type TXT -Name _amazonses -Value "G3LNeKkT8eYmQLeyAp" -Comment "confirm domain ownership"
            Create a TXT record to set _amazonses.mypowershell.space to "G3LNeKkT8eYmQLeyAp" and confirm domain ownership. Will use default TTL (300) and no comment.
        .PARAMETER Domain
            Defines a the Domain name of the domain which DNS zone is to be edited E.g.:
            1. mypowershell.space
            2. amazon.com
            3. google.com.
            4. facebook.com.
        .PARAMETER Type
            Defines a type of a DNS record: A, TXT, MX, CNAME, NS, SOA, AAAA Or PTR
            Most likely won't support all. If you mod the script and add functionality, let me know!
        .PARAMETER Name
            Defines a name of a DNS record: www, mail, intranet, dev...
            If Not specified or it is the same as the domain name or it is "@", the root domain record will be updated
        .PARAMETER Value
            Defines a value of DNS record:
            1. 192.168.0.1
            2. "ZTJGIJ4OIJS9J3560S"
        Bear in mind which record type is numerical and which textual!
        .PARAMETER TTL
            Defines a TTL of DNS record. I shouldn't really need to explain this :-)
            Not mandatory, defaults to 300.
        .PARAMETER Comment
            Defines an optional R53 comment.
            Not mandatory, not included if not explicitly defined.
    #>
    Param (
        [Parameter(Mandatory=$True)]
        [String]   $Domain,
        [Parameter(Mandatory=$True)]
        [ValidateSet("A","CNAME","TXT","MX","AAAA","PTR","NS","SOA")]
        [String]   $Type,
        [String]   $Name,
        [Parameter(Mandatory=$True)]
        [String]   $Value,
        [Int]      $TTL = 300,
        [String]   $Comment
    )

    if ($Domain.Substring($Domain.Length-1) -ne ".") {$Domain = $Domain + "."}
    if ($Name -eq $Domain -or $Name -eq "@"){Clear-Variable Name}
    if ($Name -and $Name.Substring($Name.Length-1) -ne ".") {$Name = $Name + "."}

    $Change                          = New-Object Amazon.Route53.Model.Change
    $Change.Action                   = "UPSERT"
    $Change.ResourceRecordSet        = New-Object Amazon.Route53.Model.ResourceRecordSet
    $Change.ResourceRecordSet.Name   = "$Name$Domain"
    $Change.ResourceRecordSet.Type   = $Type
    $Change.ResourceRecordSet.TTL    = $TTL
    $Change.ResourceRecordSet.ResourceRecords.Add(@{Value=if ($Type -eq "TXT") {"""$Value"""} else {$Value}})

    $HostedZone = @(Get-R53HostedZones | Where-Object {$_.Name -eq $Domain})
    If (!$HostedZone) {Write-Error "No Route 53 Hosted Zone found for $Domain"}
    If ($HostedZone.Count -gt 1) {Write-Warning "More than 1 Hosted Zone found, using $($HostedZone[0].Id)"}

    $Parameters = @{
        HostedZoneId        = $HostedZone[0].Id
        ChangeBatch_Change  = $Change 
        ChangeBatch_Comment = $Comment
    }
    Edit-R53ResourceRecordSet @Parameters
}
