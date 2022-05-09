Function Invoke-CCApproveMergePullRequest {
    [CmdletBinding()]
    Param(
        $RepositoryName,          
        $ProfileName,           
        $Region,
        $PullRequestId
    )
    $ErrorActionPreference    = "Stop"
    $Repo                     = @{RepositoryName = $RepositoryName}
    $AWSProfile               = @{
        ProfileName = $ProfileName
        Region      = $Region
    }
    if ($PullRequestId){
        $PullRequestId        = @{PullRequestId = $PullRequestId}
    } Else {
        Write-Warning "No Pull Request Id specified, getting latest one"
        
        If (($LatestPullRequest = @(Get-CCPullRequestList @Repo @AWSProfile -PullRequestStatus OPEN)[0])) {
            $PullRequestId        = @{PullRequestId = $LatestPullRequest}
        } else {
            Write-Error "-PullRequestId not specified and there are no open Pull Requests"
        }
    }
    $PullRequest              = (Get-CCPullRequest @PullRequestId @AWSProfile)
    If ($PullRequest.PullRequestStatus.Value -EQ "CLOSED"){
        Write-Error "Pull Request $($PullRequestId.PullRequestId) is already closed and can not be merged"
    }
    $PullRequestId.RevisionId = $PullRequest.RevisionId
    $DiffParams = @{
        AfterCommitSpecifier  = $PullRequest.PullRequestTargets.DestinationCommit
        BeforeCommitSpecifier = $PullRequest.PullRequestTargets.SourceCommit
    }
    Write-Host "Changes for Pull Request " $PullRequestId.PullRequestId
    foreach ( $Change in Get-CCDifferenceList @Repo @AWSProfile @DiffParams){
        switch ($Change.ChangeType.Value) {
            "M" {
                Write-Host "Modified " -NoNewline -ForegroundColor Yellow
                Write-Host $Change.AfterBlob.Path
                $AfterBlob    = (Get-CCBlob -BlobId $Change.AfterBlob.BlobId @Repo @AWSProfile)
                $AfterString  = ([System.IO.StreamReader]::new($AfterBlob)).ReadToEnd()  -split '\r?\n'
                $BeforeBlob   = (Get-CCBlob -BlobId $Change.BeforeBlob.BlobId @Repo @AWSProfile)
                $BeforeString = ([System.IO.StreamReader]::new($BeforeBlob)).ReadToEnd() -split '\r?\n'
                $Compare      = Compare-Object -ReferenceObject $AfterString -DifferenceObject $BeforeString -IncludeEqual
                $LineCount    = 0
                foreach ($Line in $Compare){
                    $LineCount ++
                    if($Line.SideIndicator -EQ "<="){
                        $LineColor = "Red"
                        $LineMarker = "-"
                        Write-Host $LineCount" " -NoNewline
                        Write-Host $LineMarker $Line.InputObject -ForegroundColor $LineColor
                    } 
                    elseif ($Line.SideIndicator -EQ "=>"){
                        $LineColor = "Green"
                        $LineMarker = "+"
                        Write-Host $LineCount" " -NoNewline
                        Write-Host $LineMarker $Line.InputObject -ForegroundColor $LineColor
                    }  
                    
                }
                Write-Host ""
            } "D" {
                Write-Host "Added " -NoNewline -ForegroundColor Green
                Write-Host $Change.BeforeBlob.Path
                $BeforeBlob    = (Get-CCBlob -BlobId $Change.BeforeBlob.BlobId @Repo @AWSProfile)
                $BeforeString = ([System.IO.StreamReader]::new($BeforeBlob)).ReadToEnd() -split '\r?\n'
                $LineCount    = 0
                foreach ($Line in $BeforeString){
                    $LineCount ++
                    Write-Host $LineCount -NoNewline
                    Write-Host " + "  $Line -ForegroundColor Green
                }
                Write-Host ""
            } "A" {
                Write-Host "Deleted " -NoNewline -ForegroundColor Red
                Write-Host $Change.AfterBlob.Path
                Write-Host ""
            } "R" {
                Write-Host "Renamed File " $Change.BeforeBlob.Path "to" $Change.AfterBlob.Path
            }
        }
    }
    Write-Host "Hit Ctrl-C to abort, or to approve and merge "
    Pause
    Update-CCPullRequestApprovalState @PullRequestId @AWSProfile -ApprovalState APPROVE
    $MergeOptionsParams = @{
        DestinationCommitSpecifier = $PullRequest.PullRequestTargets.DestinationCommit
        sourceCommitSpecifier      = $PullRequest.PullRequestTargets.SourceCommit
    }
    $MergeOptionsList = (Get-CCMergeOption @Repo @MergeOptionsParams @AWSProfile).MergeOptions
    $Mergeable = (Get-CCMergeConflict -MergeOption $MergeOptionsList[0] @Repo @AWSProfile @MergeOptionsParams).Mergeable
    If($Mergeable) {
        Write-Host "Merging by" $MergeOptionsList[0]
        $MergeParams = @{
            PullRequestId  = $PullRequestId.PullRequestId
            SourceCommitId = $PullRequest.PullRequestTargets.SourceCommit
        }
        If ("FAST_FORWARD_MERGE" -In $MergeOptionsList){
            Merge-CCPullRequestByFastForward @MergeParams @AWSProfile @Repo | Out-Null
        } elseif ('SQUASH_MERGE'-In $MergeOptionsList){
            Write-Host "Details needed for Squash Commit: "
            $MergeParams.AuthorName     = Read-Host "Name"
            $MergeParams.Email          = Read-Host "Email"
            $MergeParams.CommitMessage  = Read-Host "Commit message"
            Merge-CCPullRequestBySquash @MergeParams @AWSProfile @Repo | Out-Null
        }
        Start-Sleep 2
        if (($PullRequest = Get-CCPullRequest -PullRequestId $PullRequestId.PullRequestId @AWSProfile).PullRequestStatus -EQ "Closed"){
            Write-Host "Merge Successful, removing branch" $PullRequest.PullRequestTargets.SourceReference
            Remove-CCBranch @Repo @AWSProfile -BranchName $PullRequest.PullRequestTargets.SourceReference
        }
    } else {
        Write-Error "There are Merge Conflicts, please resolve"
    }
}