function Remove-CMS3DeleteMarkers    {
    <#
.Synopsis
    Removes Bulk S3 Delete Marks from a versioning enabled bucket
.DESCRIPTION
    Changes the EC2 instance type of a running instance by shutting it down, changing the instance type and starting it again in one cmdlet or leaves it stopped if it was stopped.

.NOTES   
    Name:        Remove-CMS3DeleteMarkers
    Author:      Chad Miles
    DateUpdated: 2017-06-10
    Version:     1.0.0
    Requires:    AWSPowerShell Module Version 3.3.104.0 or later

.EXAMPLE
   C:\> Remove-CM3DeleteMarkers -BucketName my-versioning-bucket
   a
DeleteMarker DeleteMarkerVersionId            Key            VersionId                       
------------ ---------------------            ---            ---------                       
True         ILp1td9zKFlf.RrLIW66P1HdkTGaon9. file1.log      ILp1td9zKFlf.RrLIW66P1HdkTGaon9.
True         L9EjbEVdOpTdLEBYetX0GolyQ5x4M38R log1.log       L9EjbEVdOpTdLEBYetX0GolyQ5x4M38R
True         U1zh0HjKgNCHvRIaRXauXfIGZihP3.Jn example1.txt   U1zh0HjKgNCHvRIaRXauXfIGZihP3.Jn
True         XkpRNOcYBkMdTWbRxbMCPz3ttAEu5pxV sample.log     XkpRNOcYBkMdTWbRxbMCPz3ttAEu5pxV
True         MvZO0AQ.BqpIC.0utbLQ4kB_lCSKsZs7 test.log       MvZO0AQ.BqpIC.0utbLQ4kB_lCSKsZs7

   In this example, all delete markers in the S3 bucket are found and removed in batches of 1000.

.EXAMPLE
   C:\> Remove-CMS3DeleteMarkers -BucketName my-versioning-bucket -MatchTerm file1

DeleteMarker DeleteMarkerVersionId            Key            VersionId                       
------------ ---------------------            ---            ---------                       
True         ILp1td9zKFlf.RrLIW66P1HdkTGaon9. file1.log      ILp1td9zKFlf.RrLIW66P1HdkTGaon9.

In this example, only the delete markers for files that have the word "file" in their key name are removed

   #>
    Param (
        [Parameter(Mandatory=$True)]
        [string] $BucketName,
        [string] $MatchTerm
    )
    $InputObject = (Get-S3Version -BucketName $BucketName).Versions | Where {$_.IsDeleteMarker -eq "True" -and $_.key -like "*$MatchTerm*"}
    While ($InputObject) {
        $Workingset = $InputObject | Select -First 1000
        Remove-S3Object -Force -InputObject $Workingset
        Foreach ($Item in $Workingset){
            $InputObject = $InputObject | Where {$_ -notcontains $Item}
        }
    }
}
