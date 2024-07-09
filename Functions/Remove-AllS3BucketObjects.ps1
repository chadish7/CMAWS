Function Remove-AllS3BucketObjects{
    Param(
        [parameter(Mandatory=$true)]
        $BucketName,
        $Region = 'us-east-1',
        $ProfileName
    )
    $GeneralParams = @{
        Region     = $Region
        BucketName = $BucketName
    }
    If ($ProfileName){ 
        $GeneralParams.ProfileName = $ProfileName 
    }
    If (($BucketObjects = (Get-S3Object @GeneralParams).Key)){
        Write-Host "Emptying Bucket $BucketName of $($BucketObjects.Count) Objects"
        $FileCounter = 0
        While ($FileCounter -LT $BucketObjects.Count){
            $StartMarker = $FileCounter
            $FileCounter += 500 
            $EndMarker = $FileCounter -GE $BucketObjects.Count ? $BucketObjects.Count -1 : $FileCounter
            Remove-S3Object -Force @GeneralParams -KeyCollection $BucketObjects[$StartMarker..$EndMarker] | Out-Null
        } 
    }
}