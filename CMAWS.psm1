#Requires -version 3.0
function Convert-TextToSpeech        {
<#
.Synopsis
    Converts text files into audio files.
.DESCRIPTION
    Parses the contents of multiple text files and outputs each file to an audio file by using Amazon's Polly service (https://aws.amazon.com/polly/)

.NOTES   
    Name:        Convert-TextToSpeech
    Author:      Chad Miles
    DateUpdated: 2017-08-16
    Version:     1.3.0

.EXAMPLE
   Convert-TextToSpeech input.txt -Voice Joanna

   This will output input.mp3 using Amy voice
.EXAMPLE
   Convert-TextToSpeech *.txt -Voice Amy -OutputFormat ogg
   
   This will convert all the .txt files to .ogg files in Joanna voice.
#>
    [CmdletBinding()]
    [Alias('tts')]
    Param (
        #The Input file(s), wilcards and just pointing to a folder itself work fine, just know that it will suck in what you ever you give it.
        [Parameter(Mandatory=$true)]
        [string[]]  $InputFiles, 
        #Format of the output audio in either mp3, ogg or pcm
        [ValidateSet("mp3", "ogg", "pcm")]
        [string]    $OutputFormat = "mp3",
        #The voice used, default is Amy (English - UK), for all voices please run Get-POLVoice | select -ExpandProperty Id
        [string]    $Voice = "Amy"
    )
    if ($OutputFormat -eq "pcm"){$FileExtension = "wav"}
    else {$FileExtension = $OutputFormat}
    $ErrorActionPreference = "Stop"
    Write-Verbose "Validating Voice"
    $VoiceIds   = (Get-POLVoice).Id.Value
    if ($VoiceIds -notcontains $Voice) {
        Write-Error "$Voice is not a valid voice, Valid voices are $VoiceIds"
    }
    $PreText        = '<speak>'
    $PostText       = '<break time="350ms"/></speak>'
    $PollyLimit     = 1500
    Foreach ($InputFile in Get-ChildItem $InputFiles) {
        
        $Text       = Get-Content $InputFile
        $LineCount     = 1
        Write-Verbose "Checking $InputFile for long lines"
        Foreach ($Line in $Text){
            $Line   = $Line.Replace('&',' and ').Replace('  ',' ')
            If ($Line.Length -ge $PollyLimit-($PreText.Length + $PostText.Length)){
                $ShortName = $InputFile.Name
                Write-Warning "$ShortName was skipped as Line $LineCount is longer than $PollyLimit characters, which is the longest we can submit to Polly excluding SSML tags and spaces"
                $LongLines = $true
            }
            $LineCount++
        }
        If (!$LongLines){
            Write-Verbose "Processing $InputFile"
            $LineCount    = 1
            $BaseName     = $InputFile.BaseName
            $Directory    = $InputFile.Directory
            $OutputFile   = "$Directory\$BaseName.$FileExtension"
            $OutputStream = New-Object System.IO.FileStream $OutputFile, Create
            Try {
                Foreach ($Line in $Text){
                    $Line         = $Line.Replace('&',' and ').Replace('  ',' ')
                    (Get-POLSpeech -Text $PreText$Line$PostText -TextType ssml -VoiceId $Voice -OutputFormat $OutputFormat).AudioStream.CopyTo($OutputStream)
                    $LineCount++
                }
            } Catch {
                Write-Host -ForegroundColor Red "Error while processing file"$File.FullName" in Line "$LineCount":" $PSItem.Exception.InnerException
                $OutputStream.Close()
                $ProcessingFailed = $true
            } 
            If (!$ProcessingFailed){
                (Get-POLSpeech -Text '<speak><break time="2s"/></speak>' -TextType ssml -VoiceId $Voice -OutputFormat $OutputFormat).AudioStream.CopyTo($OutputStream)
                $OutputStream.Close()
                $OutputProperties = @{
                    OutputFile    = "$BaseName.$FileExtension"
                    InputFile     = $InputFile.Name
                }
                New-Object -TypeName PSObject -Property $OutputProperties
            } else {if ( $ProcessingFailed) {Clear-Variable ProcessingFailed}}
        } else {if ($LongLines) {Clear-Variable LongLines}}
    }
}
Function Stop-CmEc2InstanceWait      {
<#
.Synopsis
    Stops an instance and waits for stop
.DESCRIPTION
    Stops an EC2 instance and waits for the instance to enter the stopped state before continueing

.NOTES   
    Name:        Stop-CMEC2InstanceWait
    Author:      Chad Miles
    DateUpdated: 2017-08-16
    Version:     1.0.0

.EXAMPLE
   PS C:\> Stop-CMEC2InstanceWait -InstanceId 1234567890abcdef
   Stopping Instance 1234567890abcdef ........

   This will stop the instance 1234567890abcdef in the default region.
.EXAMPLE
   PS C:\> Stop-CMEC2InstanceWait -InstanceId 1234567890abcdef, 0987654321fedcba
   Stopping Instance 1234567890abcdef ........
   Stopping Instance 0987654321fedcba ........

   This will stop the instances specified in the default region.
.EXAMPLE
   PS C:\> (Get-EC2Instance).Instances | Stop-CMEC2InstanceWait
   Stopping Instance 1234567890abcdef ........
   Stopping Instance 0987654321fedcba ........

   This will stop the instances piped in from the Get-EC2Intances cmdlet in the default region.
#>    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory                = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]] $InstanceId,
        [string]   $Region,
        #If set, doesn't check if Instance is running and assumes it is, and tries to stop and then start it again afterwards.
        [switch]   $NoCheck
        
    )
    BEGIN {
        $ErrorActionPreference = "Stop"
        If ($Region){
            $AllRegions    = (Get-AWSRegion).Region
            If ($AllRegions -notcontains $Region) {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS {
        foreach ($Instance in $InstanceId){
            $Parameters         = @{InstanceID  = $Instance}
            If ($Region)          {$Parameters.add('Region',$Region)}
            If (!$NoCheck) {
                $InstanceStartInfo  = (Get-EC2Instance @Parameters).Instances
                $InstanceStatus     = $InstanceStartInfo.State.Name.Value
            } else {$InstanceStatus = "running"}
            If ($InstanceStatus -ne "stopped") {
                Write-Host "Stopping Instance $Instance"
                $StopInstance       = Stop-EC2Instance @Parameters
                While ($InstanceStatus -ne "stopped"){
                    Start-Sleep -Seconds 3
                    $InstanceStatus = (Get-EC2Instance @Parameters).Instances.State.Name.Value
                    Write-Host "." -NoNewline
                }
                Write-Host ""
            }
        }
    }
}
Function Get-CmEc2InstanceTypes      {
    Param ($Region)
    if (-not $Region) {$Region  = "us-east-1"}
    If (-not $Global:PricingObject)
    {
        $OnDemandPricing= Invoke-RestMethod -uri http://a0.awsstatic.com/pricing/1/ec2/mswin-od.min.js
        $IntroText             = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright "+((Get-Date).Year)+" Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $IntroText2            = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright "+((Get-Date).AddDays(-90).Year)+" Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $OnDemandPricing       = $OnDemandPricing.TrimStart($IntroText)
        $OnDemandPricing       = $OnDemandPricing.TrimStart($IntroText2)
        $OnDemandPricing       = $OnDemandPricing.TrimEnd(');')
        $Global:PricingObject  = ($OnDemandPricing | ConvertFrom-Json).config.regions
    }
    $RegionPrices          = $PricingObject | where {$_.region -eq $Region}
    $RegionPrices.instancetypes.sizes.size
}
Function Get-Ec2WindowsOndemandPrice {
<#
.Synopsis
    Gets the price, per hour, of a Windows EC2 instance type.
#>
    Param(
        #The Instance type you wish to change the instance to, e.g. m4.large. To see all instance types see https://aws.amazon.com/ec2/instance-types/
        [Parameter(Mandatory=$true)]
        [string] $InstanceType,
        [Parameter(Mandatory=$true)]
        [string] $Region
    )
    $ErrorActionPreference = "Stop"
    $AllRegions            = (Get-AWSRegion).Region
    If ($AllRegions -notcontains $Region) {Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"}
    If (!$Global:PricingObject)
    {
        $OnDemandPricing= Invoke-RestMethod -uri http://a0.awsstatic.com/pricing/1/ec2/mswin-od.min.js
        $IntroText             = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright "+((Get-Date).Year)+" Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $IntroText2            = "/* `n* This file is intended for use only on aws.amazon.com. We do not guarantee its availability or accuracy.`n*`n* Copyright "+((Get-Date).AddDays(-90).Year)+" Amazon.com, Inc. or its affiliates. All rights reserved.`n*/`ncallback(" | Out-String
        $OnDemandPricing       = $OnDemandPricing.TrimStart($IntroText)
        $OnDemandPricing       = $OnDemandPricing.TrimStart($IntroText2)
        $OnDemandPricing       = $OnDemandPricing.TrimEnd(');')
        $Global:PricingObject  = ($OnDemandPricing | ConvertFrom-Json).config.regions
    }
    $RegionPrices          = $PricingObject | where {$_.region -eq $Region}
    $AllInstances          = $RegionPrices.instancetypes.sizes
    $InstanceEntry         = $AllInstances| where {$_.size -eq $InstanceType}
    $Price                 = $InstanceEntry.valuecolumns.prices.usd
    Write-Output $Price
}
Function Get-CmEc2ImageId            {
    [CmdletBinding(DefaultParameterSetName='Base')]
    Param(
        [Parameter(Position=0)]
        [ValidateSet(2016, "2012R2", 2012, "2008R2", 2008, 2003)]
        [string] $OsVersion="2012R2",

        [Parameter(ParameterSetName='Base')]
        [switch] $Base=$true,

        [Parameter(ParameterSetName='SQL',
                   Position=1)]
        [ValidateSet("SQL2014SP1","SQL2014SP2","SQL2016","SQL2016SP1","SQL2017","SQL2012SP3","SQL2012SP2","SQL2008R2SP3","SQL2008SP4","SQL2005SP4")]
        [string] $SqlVersion,

        [Parameter(ParameterSetName='SQL',
                   Position=2)]
        [ValidateSet("Express", "Web","Standard","Enterprise")]
        [string] $SqlEdition = "Standard",

        [switch] $Core,

        [string] $Region,

        [ValidateSet(
            "Chinese_Traditional",
            "Chinese_Simplified",
            "Czech",
            "Dutch",
            "English",
            "French",
            "German",
            "Hungarian",
            "Korean",
            "Japanese",
            "Polish",
            "Portuguese_Brazil",
            "Russian",
            "Spanish",
            "Swedish",
            "Turkish"
            )]
        [string] $Language = "English"
    )
    $ErrorActionPreference = "Stop"
    if ($SqlVersion) 
    {
        Clear-Variable Base
        $SqlVersion = $SqlVersion.ToUpper()
        $SqlEdition = $SqlEdition.Substring(0,1).ToUpper() + $SqlEdition.Substring(1).ToLower()
    }
    $OSVersion             = $OSVersion.ToUpper()
    $Language              = $Language.Substring(0,1).ToUpper() + $Language.Substring(1).ToLower()
    
    $BaseText = "/aws/service/ami-windows-latest/Windows_Server-"
    if ($SqlVersion.Length -eq 10) 
    {
        $SqlYear = $SqlVersion.Substring(3,4)
        $SqlSp   = $SqlVersion.Substring($SqlVersion.Length-3)
        $SqlText =  "SQL_"+$SqlYear+"_"+$SqlSp+"_"+$SqlEdition
    }
    elseif ($SqlVersion -eq "2008R2SP3")
    {
        $SqlText =  "SQL_2008_R2_SP3_"+$SqlEdition
    }
    elseif  ($SqlVersion.Length -eq 7)
    {
        $SqlYear = $SqlVersion.Substring(3,4)
        $SqlText =  "SQL_"+$SqlYear+"_"+$SqlEdition
    }
     
    if ($OsVersion -ne "2016" -and $SqlYear -eq 2017)                                        {Write-Error "SQL Server 2017 and higher only supported on Windows Server 2016"}
    if (!($OsVersion -eq "2016" -or $OsVersion -eq "2012R2") -and $SqlYear -eq 2016)         {Write-Error "SQL Server 2016 only supported on Windows Server 2012R2 and 2016"}
    if (!($OsVersion -eq "2012R2" -or $OsVersion -eq "2012") -and $SqlYear -eq 2014)         {Write-Error "SQL Server 2014 only supported on Windows Server 2012 and 2012R2"}
    if (!($OsVersion -eq "2008R2" -or $OsVersion -eq "2012") -and $SqlYear -eq 2012)         {Write-Error "SQL Server 2012 only supported on Windows Server 2008R2 and 2012"}
    if ($OsVersion -ne "2008" -and $SqlYear -eq 2008)                                        {Write-Error "SQL Server 2008 only supported on Windows Server 2008"}
    if ($OsVersion -ne "2003" -and $SqlYear -eq 2005)                                        {Write-Error "SQL Server 2005 only supported on Windows Server 2003"}
    if ($Core -and -not ($OsVersion -ne "2012R2" -or $OsVersion -ne 2016 -or $OsVersion -ne "2008R2")) {Write-Error "Core AMIs only available for Windows Server 2008R2, 2012R2 and 2016"}
    
    if ($OsVersion -eq "2016")     
    {
        if ($Core) {$SearchString = $BaseText+"2016-"+$Language+"-Core"}
        else       {$SearchString = $BaseText+"2016-"+$Language+"-Full"}
        if ($Base) {$SearchString = $SearchString+"-Base"}
        else       {$SearchString = $SearchString+"-"+$SqlText}
    }
    if ($OsVersion -eq "2012R2")   
    {
        if ($Base) 
        {
            if     ($Core) {$SearchString = $BaseText+"2012-R2_RTM-"+$Language+"-64Bit-Core"}
            else {$SearchString = $BaseText+"2012-R2_RTM-"+$Language+"-64Bit-Base"}
        }
           
        else 
        {
            if     ($Core) {Write-Error "SQL Server not available on Windows 2012 R2 Core"}
            else {$SearchString = $BaseText+"2012-R2_RTM-"+$Language+"-64Bit-"+$SqlText}
        }
    }

    if ($OsVersion -eq "2012")     
    {
        if ($Base) {$SearchString = $BaseText+"2012-RTM-"+$Language+"-64Bit-Base"}
        else       {$SearchString = $BaseText+"2012-RTM-"+$Language+"-64Bit-"+$SqlText}
    }
    if ($OsVersion -eq "2008R2")   
    {
        if     ($Core) {$SearchString = $BaseText+"2008-R2_SP1-"+$Language+"-64Bit-Core"}
        elseif ($Base) {$SearchString = $BaseText+"2008-R2_SP1-"+$Language+"-64Bit-Base"}
        else           {$SearchString = $BaseText+"2008-R2_SP1-"+$Language+"-64Bit-"+$SqlText}
    }
    if ($OsVersion -eq "2008")     
    {
        if ($Base) {$SearchString = $BaseText+"2008-SP2-"+$Language+"-64Bit-Base"}
        else       {$SearchString = $BaseText+"2008-SP2-"+$Language+"-64Bit-"+$SqlText}
    }
    if ($OsVersion -eq "2003")     
    {
        if ($Base) {$SearchString = $BaseText+"2003-R2_SP2-"+$Language+"-64Bit-Base"}
        else       {$SearchString = $BaseText+"2003-R2_SP2-"+$Language+"-64Bit-"+$SqlText}
    }
    $Parameters = @{Name = $SearchString}
    if ($Region) {$Parameters.Add('Region', $Region)}
    (Get-SSMParameter @Parameters).Value
}
Function Set-R53Record               {
<# 
.SYNOPSIS 
    Made for easier interaction with Amazon Route 53 DNS service.
.DESCRIPTION 
    Run the script in CREATE/UPDATE mode in order to add or modify DNS records in Amazon Route 53.
    Requires 4 parameters - Domain name and type, name and the value of DNS record.
.NOTES 
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
    Defines a domain which DNS zone is to be edited:
    1. mypowershell.space
    2. amazon.com
    3. google.com.
    4. facebook.com.
.PARAMETER Type
    Defines a type of a DNS record: A, TXT, MX, CNAME, NS...
    Most likely won't support all. If you mod the script and add functionality, let me know!
.PARAMETER Name
    Defines a name of a DNS record: www, mail, intranet, dev...
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
        [String]   $Type,
        [Parameter(Mandatory=$True)]
        [String]   $Name,
        [Parameter(Mandatory=$True)]
        [String]   $Value,
        [Int]      $TTL = 300,
        [String]   $Comment
    )

    if ($Domain.Substring($Domain.Length-1) -ne ".") {$Domain = $Domain + "."}

    $Change                          = New-Object Amazon.Route53.Model.Change
    # UPSERT: If a resource record set doesn't already exist, AWS creates it. If it does, update it with values in the request.
    $Change.Action                   = "UPSERT"
    $Change.ResourceRecordSet        = New-Object Amazon.Route53.Model.ResourceRecordSet
    $Change.ResourceRecordSet.Name   = "$Name.$Domain"
    $Change.ResourceRecordSet.Type   = $Type
    $Change.ResourceRecordSet.TTL    = $TTL
    $Change.ResourceRecordSet.ResourceRecords.Add(@{Value=if ($Type -eq "TXT") {"""$Value"""} else {$Value}})

    $HostedZone = Get-R53HostedZones | Where-Object {$_.Name -eq $Domain}

    $Parameters = @{
        HostedZoneId        = $HostedZone.Id
        ChangeBatch_Change  = $Change 
        ChangeBatch_Comment = $Comment
    }
    Edit-R53ResourceRecordSet @Parameters
}
Function Set-CmEc2DnsName            {
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [string[]]  $InstanceId,
        [Parameter(Mandatory=$true)]
        [string]    $DomainName,
        [string]    $Region,
        [string]    $InstanceName
    )
    BEGIN 
    {
        $ErrorActionPreference      = "Stop"
        If ($Region)
        {
            $AllRegions = (Get-AWSRegion).Region
            If ($AllRegions -notcontains $Region) 
            {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceID)
        {
            $Parameters       = @{InstanceID  = $Instance}
            If ($Region)        {$Parameters.add('Region',$Region)}
            $RunningInstance  = (Get-EC2Instance @Parameters).RunningInstance
            $CurrentState     = $RunningInstance.State.Name.Value
            if ($CurrentState -like "stop*" -or $CurrentState -like "term*"-or $CurrentState -like "shut*" -or !$CurrentState)
            {
                Write-Error "Instance $Instance stopped, stopping or terminated or does not exist, Please start or specify a valid instance"
            }
            If ((Get-Ec2Subnet -SubnetId $RunningInstance.SubnetId -Region $Region).MapPublicIpOnLaunch -eq $true -and !$RunningInstance.PublicIpAddress)
            {
                $Counter          = 1
                While ($CurrentState -ne "running" -and !$RunningInstance.PublicIpAddress)
                {
                    
                    Start-Sleep -Seconds 1
                    $Counter++
                    $RunningInstance  = (Get-EC2Instance @Parameters).RunningInstance
                    $CurrentState     = $RunningInstance.State.Name.Value
                    if ($Counter -ge 30)
                    {
                        Write-Error "Instance $Instance took too long to start, aborting. WARNING Instance may still start and incur charges."
                    }
                }
            }
            If ($InstanceName) {$HostName  = $InstanceName+"."+$DomainName}
            Else 
            {
                $InstanceName          = $RunningInstance.Tags | Where-Object {$_.Key -eq "Name"} | Select -ExpandProperty Value
            
                If (!$InstanceName) 
                {
                    Write-Error "No Name Tag on instance $Instance, can't apply DNS Name."
                    $HostName     = $RunningInstance.PublicDnsName
                } 
                Else 
                {
                    $HostName  = $InstanceName+"."+$DomainName
                }
            }
            
            If ($RunningInstance.PublicIpAddress) 
            {
                Set-R53Record -Domain $DomainName -Type A -Name $InstanceName -Value $RunningInstance.PublicIpAddress -TTL 30 | Out-Null
            } 
            Else 
            {
                Set-R53Record -Domain $DomainName -Type A -Name $InstanceName -Value $RunningInstance.PrivateIpAddress -TTL 30 | Out-Null
            }
            $ObjProperties = @{
                InstanceID   = $Instance
                HostName     = $HostName
                CurrentState = $CurrentState
            }
            New-Object -TypeName PsObject -Property $ObjProperties
        }
    }
    END{}
}
Function New-CmEC2Instance           {
    <#
.Synopsis
    Creates a Windows EC2 On demand or spot Instance with minimal input.
.DESCRIPTION
    Creates a Windows EC2 On demand or spot Instance and, if a Name and DomainName are specified, creates or updates the Route 53 DNS entry for the instance and applies a Name Tag.

.NOTES   
    Name:        New-CMEC2Instance
    Author:      Chad Miles
    DateUpdated: 2017-05-02
    Version:     1.2.0

.EXAMPLE
   C:\> New-CMEC2Instance -InstanceType t2.micro -Region us-east-1 -DomainName mydomain.com -Name MyInstance
   
   InstanceID            : i-1234567890abcdef
   Region                : us-east-1
   Name                  : MyInstance
   Hostname              : MyInstance.Mydomain.com
   InstanceType          : t2-micro
   BidPrice              : 
   OnDemandPrice         : 0.017
   Savings               : 0 %
   ImageName             : WINDOWS_2016_BASE
   ImageID               : ami-58a1a73e
   KeyName               : MyKeyPair
   
.EXAMPLE
   C:\> New-CMEC2Instance -InstanceType t2.micro -Region us-east-1 -Name MyInstance
   
   InstanceID            : i-1234567890abcdef
   Region                : us-east-1
   Name                  : MyInstance
   Hostname              : ec2-34-248-2-178.eu-west-1.compute.amazonaws.com
   InstanceType          : t2-micro
   BidPrice              : 
   OnDemandPrice         : 0.017
   Savings               : 0 %
   ImageName             : WINDOWS_2016_BASE
   ImageID               : ami-58a1a73e
   KeyName               : MyKeyPair

.EXAMPLE
   C:\> New-CMEC2Instance -InstanceType t2.micro -Region us-east-1 -Name MyInstance -DomainName mydomain.com -OSVerion 2012R2
   
   InstanceID            : i-1234567890abcdef
   Region                : us-east-1
   Name                  : MyInstance
   Hostname              : MyInstance.Mydomain.com
   InstanceType          : t2-micro
   BidPrice              : 
   OnDemandPrice         : 0.017
   Savings               : 0 %
   ImageName             : WINDOWS_2012R2_BASE
   ImageID               : ami-40003a26
   KeyName               : MyKeyPair

.EXAMPLE
   C:\> New-CMEC2Instance -InstanceType t2.micro -Region us-east-1 -Name MyInstance -DomainName mydomain.com -SpotRequest
   WARNING: Spot Instances not available for T1 and T2 instance types, switching to on demand.

   InstanceID            : i-1234567890abcdef
   Region                : us-east-1
   Name                  : MyInstance
   Hostname              : MyInstance.Mydomain.com
   InstanceType          : t2-micro
   BidPrice              : 
   OnDemandPrice         : 0.017
   Savings               : 0 %
   ImageName             : WINDOWS_2016_BASE
   ImageID               : ami-40003a26
   KeyName               : MyKeyPair

.EXAMPLE
   C:\> New-CMEC2Instance -InstanceType m3.medium -Region us-east-1 -Name MySpotInstance -DomainName mydomain.com -SpotRequest
   
   InstanceID            : i-1234567890abcdef
   Region                : us-east-1
   Name                  : MySpotInstance
   Hostname              : MySpotInstance.Mydomain.com
   InstanceType          : m3.medium
   BidPrice              : 0.0741
   OnDemandPrice         : 0.13
   Savings               : 55 %
   ImageName             : WINDOWS_2016_BASE
   ImageID               : ami-58a1a73e
   KeyName               : MyKeyPair

#>
    [CmdletBinding(SupportsShouldProcess=$true,
                   DefaultParameterSetName='SearchBaseIds')]
    Param (
        [Parameter(Mandatory=$true)]
        $Region,
        # Applies this name tag to the instance after creation, if -DomainName is specified as well then registers a DNS CNAME for your instance using this name
        [string] $Name,
        # If -Name is also specified then a DNS CNAME is registered in this domain, provided the domain is hosted in R53 and you have rights to do so.
        [string] $DomainName,
        # WINDOWS or LINUX, Default is Windows
        [string] $OS         = "Windows",
        # Version of Windows e.g. 2012R2 or 2016. Default is 2012R2
        [ValidateSet("2016", "2012R2", "2012", "2008R2","2008","2003")]
        [string] $OsVersion = 2016,

        [Parameter(ParameterSetName='SearchBaseIds')]
        [switch] $Base=$true,

        [Parameter(ParameterSetName='SearchSqlIds',
                   Mandatory=$true)]
        [ValidateSet("SQL2014SP1","SQL2014SP2","SQL2016","SQL2016SP1","SQL2017","SQL2012SP3","SQL2012SP2","SQL2008R2SP3","SQL2008SP4","SQL2005SP4")]
        [string] $SqlVersion,

        [Parameter(ParameterSetName='SearchSqlIds',
                   Mandatory=$true)]
        [ValidateSet("Express", "Web","Standard","Enterprise")]
        [string] $SqlEdition = "Standard",

        [switch] $Core,

        # Instance Profile (with IAM Role) to attach to new Instance
        [string] $InstanceProfile,
        # Path to User data file , using Your My Documents folder as a root
        [string] $UserData,
        # What Percrentage to add to the lowest Spot Price to ensure instance's longevity
        [int]    $MarkUp     = 1,
        [Parameter(ValueFromPipeline       =$true,
            ValueFromPipelineByPropertyName=$true)]
        #Specify an AMI id like ami-2b8c8452
        [Parameter(ParameterSetName='ImageId',
                   Mandatory=$true)]
        [string] $ImageId,
        # The name of the Security Group, not the Security Group ID. The Function will get the ID. If none is specified the default Security Group is used.
        [string] $SecurityGroupName,
        # Switch to specify that a Spot instance should be created instead of On Demand. Bid price will be automatically calculated based on current bid price plus a markup percentage of which the default is 1.
        [switch] $SpotInstance,
        # The Name of the EC2 KeyPair to use when creating the instance
        [string] $KeyName,
        # The ID of the VPC you wish to use, if not specified, the default one is used.
        [string] $VpcId,
        # Last letter of the Availability Zone like a, b, c, d or e, if none specified, a is used
        [string] $AZSuffix    = "a",
        [string] $SubNetId    
    )
    DynamicParam {
        $InstanceTypes        = Get-CmEc2InstanceTypes
        $ParameterName        = 'InstanceType'
        $ParamDictionary      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $ParamAttrib          = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory= 1
        $AttribColl           = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($InstanceTypes)))
        $InstanceTypeParam    = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttribColl)
        $InstanceTypeParamDic = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $InstanceTypeParamDic.Add($ParameterName,  $InstanceTypeParam)
        return  $InstanceTypeParamDic

        $AllRegions           = (Get-AWSRegion).Region
        $ParameterName        = 'Region'
        $ParamDictionary      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $ParamAttrib          = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory= 1
        $AttribColl           = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($Regions)))
        $RegionParam         = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttribColl)
        $RegionParamDic      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RegionParammDic.Add($ParameterName,  $RegionParam)
        return  $RegionParamDic
    }
    BEGIN 
    {
        $Region = $PSBoundParameters.Region
    }
    Process {
        $InstanceType = $PSBoundParameters.InstanceType
        if ($SqlVersion) 
        {
            Clear-Variable Base
            if ($InstanceType -like "t2.*" -and $SqlEdition -ne "Express") {Write-Error "Non Express editions of SQL Server are not permited to run on t2 instance types"}
        }
        [int]$Count               = 1 
        $ErrorActionPreference    = "Stop"
        If ($InstanceType -like "t*" -and $SpotInstance) 
        {
            Write-Warning "Spot Instances not available for T1 and T2 instance types, switching to on demand."
            $SpotInstance = $false
        }
        $AvailabilityZone      = $Region+$AZSuffix
        Write-Verbose          "Geting On Demand Instance Pricing"
        $OndemandPrice         = Get-EC2WindowsOndemandPrice -InstanceType $InstanceType -Region $Region
        If ($SpotInstance) 
        {
            Write-Verbose      "Getting Current Spot Price of Instance Type and adding mark up."
            $SpotPriceCheck    = Get-EC2SpotPriceHistory -Region $Region -StartTime (Get-Date) -InstanceType $InstanceType -ProductDescription $OSLower
            $LowestSpotPrice   = ($SpotPriceCheck.Price | Measure-Object -Minimum).Minimum
            $AvailabilityZone  = ($SpotPriceCheck | Where {$_.Price -like "$LowestSpotPrice*"})[0].AvailabilityZone
            $BidPrice          = $LowestSpotPrice * (($MarkUp+100)/100)
    
            If ($OndemandPrice -gt $BidPrice) 
            {
                $Savings       = [math]::Round((($OndemandPrice - $BidPrice) / $OnDemandPrice)*100)
                Write-Verbose     "Requesting $Count $InstanceType instance(s) at $ $BidPrice/hour in $AvailabilityZone ($Savings% Savings)"
                Clear-Variable SubnetId       
            } 
            else 
            {
                $AvailabilityZone      = $Region+$AZSuffix
                Write-Warning    "OnDemand Pricing ($ $OndemandPrice) is better than Spot Price ($ $BidPrice), Launching On Demand launching in $AvailabilityZone"
                Clear-Variable SpotInstance
            
            }
        }
        if (!$ImageID) 
        {
            Write-Verbose       "Getting Current AMI for Selected OS"
            $ImageParam      = @{OsVersion = $OsVersion}
            If ($Core)       {$ImageParam.Add('Core',$true)}
            If ($Region)     {$ImageParam.Add('Region',$Region)}
            If ($SqlVersion) {$ImageParam.Add('SqlVersion',$SqlVersion)}
            If ($SqlEdition) {$ImageParam.Add('SqlEdition',$SqlEdition)}
            try{$ImageID           = Get-CMEC2ImageId @ImageParam}catch{}
        }
        if (!$ImageID) {         Write-Error "Could not find an image with Search criteria in region $Region"}
        if (!$Keyname) 
        {
            Write-Verbose       "Getting first KeyPair for Region"
            $KeyName           = (Get-EC2KeyPair -Region $Region)[0].KeyName
        }
        if (!$KeyName)          {Write-Error "No EC2 Key Pairs found in region $Region, please create one"}
        If ($UserData)          {$UserData64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($UserData))}
        If (!$SubNetId)
        { 
            If (!$VpcId)   
            {
                Write-Verbose       "Getting default VPC"
                $VpcId             = (Get-EC2Vpc -Region $Region| Where {$_.IsDefault -eq $true}).VpcId
            }
            If (!$VpcId)   {         Write-Error "Could not find default VPC in region $Region, Please specify one"}
            Write-Verbose       "Getting Subnet for name $AvailabilityZone"
            $SubNetId          = (Get-EC2Subnet -Region $Region | where {$_.AvailabilityZone -eq $AvailabilityZone -and $_.VpcId -eq $VPCid})[0].SubnetId
        } Else {
            $VpcId = (Get-EC2Subnet -Region $Region -SubnetId $SubNetId).VpcId
        }
        If (!$VpcId) {Write-Error "Could not determine VPC, check you have a default VPC in the region and if SubnetId is specified, make sure it is valid"}
    
        If ($SecurityGroupName) 
        {
            Write-Verbose       "Getting Security Group for name $SecurityGroupName"
            $SecurityGroupId   = (Get-EC2SecurityGroup -Region $Region | where {$_.GroupName -eq $SecurityGroupName -and $_.VpcId -eq $VpcId})[0].GroupId
            If (!$SecurityGroupId) {Write-Error "Security Group with $SecurityGroupName cannot be found"}
        } 
        else 
        {
            Write-Verbose       "Getting Security Group for VPC $VpcId"
            $SecurityGroupId   = (Get-EC2SecurityGroup -Region $Region | where {$_.GroupName -eq "default" -and $_.VpcId -eq $VPCId})[0].GroupId
        }
        If (!$SecurityGroupId)  {Write-Error "Could not find a Security Group with the name $SecurityGroupName in region $Region"}
    
   

        If ($SpotInstance) 
        {
            $Params            = @{
                Region             = $Region
                InstanceCount      = $Count
                SpotPrice          = $BidPrice
                Type               = "one-time"
                LaunchSpecification_ImageId       = $ImageId
                LaunchSpecification_InstanceType  = $InstanceType
                LaunchSpecification_KeyName       = $KeyName
                LaunchSpecification_SubnetId      = $SubNetId
            }
            If ($InstanceProfile) {$Params.Add("IamInstanceProfile_Name", $InstanceProfile)} 
            If ($UserData64)      {$Params.Add("LaunchSpecification_UserData", $UserData64)} 
            $SpotRequest       = Request-EC2SpotInstance @Params
            Write-Host          "Waiting for Spot Fufillment"
            If ($InstanceId) {Clear-Variable InstanceId}
            While (!$InstanceId)
            {
                $InstanceId    = (Get-EC2SpotInstanceRequest $SpotRequest.SpotInstanceRequestId).InstanceId
                Start-Sleep    2
            }
        } 
        else 
        {
            $Params            = @{
                Region               = $Region
                MinCount             = $Count
                MaxCount             = $Count
                InstanceType         = $InstanceType
                SecurityGroupId      = $SecurityGroupId
                ImageId              = $ImageId
                SubnetId             = $SubNetId
                KeyName              = $KeyName
            }
            If ($UserData64)      {$Params.Add("UserData",$UserData64)}
            If ($InstanceProfile) {$Params.Add("InstanceProfile_Name",$InstanceProfile)}
            $InstanceId       = (New-EC2Instance @Params).Instances.InstanceId
            $Savings          = 0
        }
        if ($Name) 
        {
            Write-Verbose "Applying Name Tag to instance"
            New-EC2Tag -Resource $InstanceId -Tag @{Key = "Name"; Value = $Name} -Region $Region
            If ($DomainName)
            {
                $DNSParams        = @{InstanceId    = $InstanceId}
                if($Region)        {$DNSParams.Add('Region',$Region)}
                $SetDns           = Set-CmEc2DnsName @DNSParams -DomainName $DomainName -InstanceName $Name
                $HostName         = $SetDns.Hostname
            }
            Else 
            {
            
            }
        } else {$HostName = $RunningInstance.PublicIPAddress}
        $OutputProperties = @{
            InstanceId            = $InstanceId
            Region                = $Region
            Name                  = $Name
            Hostname              = $HostName
            InstanceType          = $InstanceType
            BidPrice              = $BidPrice
            OnDemandPrice         = $OnDemandPrice
            Savings               = "$Savings %"
            ImageName             = $ImageName
            ImageId               = $ImageId
            KeyName               = $KeyName
            InstanceProfile       = $InstanceProfile
        }
        New-Object -TypeName PSObject -Property $OutputProperties
    }
}
Function Start-CmEc2Instance         {
    [CmdletBinding()]
    [Alias('Start-CmInstance')]
    Param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [string[]]  $InstanceID,
        [string]    $DomainName,
        [string]    $Region
    )
    BEGIN 
    {
        $ErrorActionPreference      = "Stop"
        If ($Region){
            $AllRegions = (Get-AWSRegion).Region
            If ($AllRegions -notcontains $Region) { 
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceID)
        {
            $Parameters       = @{InstanceID  = $Instance}
            if ($Region)        {$Parameters.add('Region',$Region)}
            $StartingInstance = Start-EC2Instance @Parameters
            If ($DomainName) {$SetDns = Set-CmEc2DnsName @Parameters -DomainName $DomainName}
            $ObjProperties    = @{
                InstanceID    = $Instance
                PreviousState = $StartingInstance.PreviousState.Name.Value              
            }
            If ($SetDns) 
            {
                $ObjProperties.Add('HostName',$SetDns.HostName)
                $ObjProperties.Add('CurrentState',$SetDns.CurrentState)
            }
            else 
            {
                $ObjProperties.Add('CurrentState',$StartingInstance.CurrentState.Name.Value)
            }
            New-Object -TypeName PsObject -Property $ObjProperties
        }
    }
    END {}
}
Function New-CmPassword              {
    <#
    .Synopsis
       Generates random passwords
    .DESCRIPTION
       Generates Random passwords and outputs as text and to Clipboard or just to clipboard
    .EXAMPLE
       PS> New-CMPassword -Easy
       Kobi2858
    .EXAMPLE
       PS> New-CMPassword
       N42v9AjCWF1J
    .EXAMPLE
       PS> New-CMPassword -ClipOnly 
       PS>
       Password is only put in clipboard and not displayed on screen.
    .EXAMPLE
       PS> $pass = New-CMPassword
       PS> Set-ADAccountPassword DOMAIN\USERNAME -NewPassword (ConvertTo-SecureString ($pass) -AsPlainText -Force)
       PS> Write-Output "Account password set to $pass"

       This will set an AD account's password to a randomly generated password and copy that password to the clipboard
    #>
    [CmdletBinding()]
    [Alias('np')]
    [OutputType([String])]
    Param
    (
        #Creates easy readable and rememberable password like Office 365's password generator
        [Switch]   $Easy, 
        #Enables the use of special characters, like !^&*(%$#)-=_+
        [Switch]   $Specials,
        #Doesn't output the password as text but rather only copies it to Clipboard
        [Switch]   $ClipOnly,
        #Specifies the length of the password. This parameter is ignored when you use the -Easy switch
        [Parameter(Position=0)]
        [int]      $Length = 12,
        #Specifies the ammount of passwords to generate, only the last one will be left in the clipboard
        [int]      $Count = 1
    )
    for ($c = 0 ; $c -lt $Count ; $c++){
        if ($easy -Eq $true) 
        {
            $digits = 48..57
            $UpperConsonants = 66..68 + 70..72 + 74..78 + 80..84 + 86..90
            $LowerConsonants = 98..100 + 102..104 + 106..110 + 112..116 + 118..122
            $LowerVowels = 97, 101, 105, 111, 117

            $first = [char](get-random -count 1 -InputObject $UpperConsonants)
            $second = [char](get-random -count 1 -InputObject $LowerVowels)
            $third = [char](get-random -count 1 -InputObject $LowerConsonants)
            $fourth = [char](get-random -count 1 -InputObject $LowerVowels)
            $numbers = $null
            for ($i=0 ; $i -lt 4; $i++)
            {
                $numbers += [char](get-random -count 1 -InputObject $digits)
            }
            $password = ($first + $second + $third + $fourth + $numbers)
        }
        Else
        {
            $digits = 48..57
            $letters = 65..90 + 97..122
            $specialchar = 33..47 + 58..64 + 91..96 + 123..126
            $password = $null
            for ($i = 0 ; $i -lt $Length ; $i++)
            {
                If ($Specials -eq $true) {$password += [char](get-random -count 1 -InputObject ($digits + $letters + $specialchar))}
                Else {$password += [char](get-random -count 1 -InputObject ($digits + $letters))}
            }
        }
        $password | Set-Clipboard
        If(!$ClipOnly) {$password}
    }
}
Function New-CmEasyPassword          {
    <#
    .Synopsis
       See New-CMPassword Help

       Alais for executing New-CMPassword -Easy -Count 1
    #>
    [Alias('npe')]
    Param(
        [int]      $Count = 1,
        [Switch]   $ClipOnly
    )
    if ($ClipOnly -eq $true) {
        New-CMPassword -Easy -Count $Count -ClipOnly
    } else {
        New-CMPassword -Easy -Count $Count
    }
}
Function Get-CmEc2Instances          {
    [Cmdletbinding()]
    Param (
        [string[]]$Region
    )
    $ErrorActionPreference = "Stop"
    $AllRegions    = (Get-AWSRegion).Region
    If (!$Region){
        $Region = $AllRegions
        Write-Warning "Getting instances for all regions, May take some time"
    } 
    Foreach ($Reg in $Region) {
        If ($AllRegions -notcontains $Reg) {Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"}
        $Instances = (Get-EC2Instance -Region $Reg).RunningInstance 
        Foreach ($Instance in $Instances) {  
            $Properties    = @{
                Name            = $Instance.Tags | Where-Object {$_.Key -eq "Name"} | Select -ExpandProperty Value
                State           = $Instance.State.Name
                InstanceType    = $Instance.InstanceType
                InstanceId      = $Instance.InstanceId
                AZ              = $Instance.Placement.AvailabilityZone
                LaunchTime      = $Instance.LaunchTime
                PublicIpAddress = $Instance.PublicIpAddress
            }
            $InstanceObject = New-Object PSObject -Property $Properties
            Write-Output $InstanceObject
        }
    }
    Write-Output $InstancesList
}
Function Stop-CMAllInstances         {
    $AllRegions = (Get-AWSRegion).Region
    foreach ($Region in $AllRegions) {
        $Instances = (Get-EC2Instance -Region $Region).RunningInstance
        foreach ($Instance in $Instances)
        {
            $Tags          = ($Instances.tags).Key
            $InstanceState = ($Instances.State).Name
            if ($Tags -notcontains "Persistent" -and $InstanceState -ne "stopped")
            {
                $InstanceID = ($Instances).InstanceId
                Write-Output "Stopping $InstanceID"
                Stop-EC2Instance -InstanceId $InstanceID -Region $Region | Out-Null
            }
        }
    }
}
Function Send-CMSSMPowerShell        {
<#
.Synopsis
    Sends PowerShell Commands to a AWS EC2 SSM Managed Instance and displays results.
.DESCRIPTION
    Sends PowerShell Commands to a SSM Managed Instance and waits for the command to finish then brings back the output from that command to the console

.NOTES   
    Name:        Send-SSMPowerShellCommand
    Author:      Chad Miles
    DateUpdated: 2017-05-06
    Version:     1.0.1

.EXAMPLE
   C:\> $SSMCommands = {Get-Service Bits}
   C:\> Send-CMSSMPowerShell  -InstanceID i-abcdef1234567890 -Command $SSMCommands | Format-List
   
   InstanceID : i-abcdef1234567890
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...
   
.EXAMPLE
   C:\> $SSMCommands = {Get-Service Bits}
   C:\> Send-CMSSMPowerShell -InstanceID i-abcdef1234567890,i-1234567890abcdef -Region us-west-2 -Command $SSMCommands | Format-List
   
   InstanceID : i-abcdef1234567890
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...

   InstanceID : i-1234567890abcdef
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...
   .EXAMPLE
   C:\> $SSMCommands = {Get-Service Bits}
   C:\> Get-SSMInstanceInformation | Send-CMSSMPowerShell -Command $SSMCommands | Format-List
   
   InstanceID : {i-abcdef1234567890}
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...

   InstanceID : {i-1234567890abcdef}
   Output     : 
                Status   Name               DisplayName                           
                ------   ----               -----------                           
                Running  BITS               Background Intelligent Transfer Ser...


#>    
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory               =$true,
            ValueFromPipeline              =$true,
            ValueFromPipelineByPropertyName=$true)]
        [string[]]    $InstanceId,
        [string]      $Region,
        [Parameter(Mandatory               =$true)]
        [ScriptBlock] $Command
    )
    BEGIN {
        $ErrorActionPreference      = "Stop"
        If ($Region){
            $AllRegions    = (Get-AWSRegion).Region
            If ($AllRegions -notcontains $Region) {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS {
        foreach ($Instance in $InstanceId){
            $Parameters    = @{InstanceID  = $Instance}
            if ($Region)     {$Parameters.add('Region',$Region)}
            $CommandID     = (Send-SSMCommand @Parameters -DocumentName "AWS-RunPowerShellScript" -Parameter @{commands="$Command"}).CommandId
            $SSMRunStatus  = $false
            While (!$SSMRunStatus) {
                Start-Sleep -Seconds 1
                $SSMCommandStatus    = (Get-SSMCommand @Parameters -CommandId $CommandID).Status.Value
                if ($SSMCommandStatus -eq "Success") {
                    $SSMRunStatus    = $true
                    $SSMOutPut       = (Get-SSMCommandInvocationDetail @Parameters -CommandId $CommandID).StandardOutputContent
                } elseif ($SSMCommandStatus -eq "Failed") {
                    $SSMRunStatus    = $true
                    Write-Error "SSM Run Command to Failed"
                }
            }
            $OutputProperties = @{
                Output        = $SSMOutPut
                InstanceID    = $Instance
            }
            $OutputObject     = New-Object -TypeName PSObject -Property $OutputProperties
            Write-Output      $OutputObject
        }
    }
    END{}
}
Function Set-CMEC2InstanceType       {
<#
.Synopsis
    Changes an EC2 instance type leaving it in the same state
.DESCRIPTION
    Changes the EC2 instance type of a running instance by shutting it down, changing the instance type and starting it again in one cmdlet or leaves it stopped if it was stopped.

.NOTES   
    Name:        Set-CMEC2InstanceType 
    Author:      Chad Miles
    DateUpdated: 2017-05-06
    Version:     1.0.0

.EXAMPLE
   C:\> Set-CMEC2InstanceType -InstanceID i-1234567890abcdef -InstanceType m4.large
   
   Shutting down Instance i-1234567890abcdef
   ........

   InstanceID          Status              InstanceType
   ----------          ------              ------------
   i-1234567890abcdef  running             m4.large

   In this example one instance was specified for changing running and was stopped, changed and started again.
   
.EXAMPLE
   C:\> (Get-EC2instances).instances | Where {$_.InstanceType -eq "t2.large"} | Set-CMEC2InstanceType -InstanceType m4.large

   Shutting down Instance i-1234567890fedcba
   ........

   InstanceID          Status              InstanceType
   ----------          ------              ------------
   i-1234567890fedcba  running             m4.large
   i-1234567890abcdef  stopped             m4.large

   In this example all the instances that were of instance type t2.large where changed to m4.large, of which there were two. However, one of the instances was in a stopped state and the other was running and they were both left in their respective states.
  
  #>    
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory                = $true,
            ValueFromPipeline               = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]] $InstanceId,
        [Parameter(ValueFromPipeline        = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string]   $Region,
        [string]   $DomainName
    )
    DynamicParam 
    {
        $Names                = Get-CmEc2InstanceTypes
        $ParameterName        = 'InstanceType'
        $ParamDictionary      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $ParamAttrib          = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory= 1
        $AttribColl           = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($Names)))
        $RuntimeParam         = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttribColl)
        $RuntimeParamDic      = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RuntimeParamDic.Add($ParameterName,  $RuntimeParam)

        return  $RuntimeParamDic
    }
    BEGIN 
    {
        $InstanceType               = $PSBoundParameters.InstanceType
        $ErrorActionPreference      = "Stop"
        If ($Region){
            $AllRegions    = (Get-AWSRegion).Region
            If ($AllRegions -notcontains $Region) {
                Write-Error "$Region is not a valid AWS Region, Valid regions are $AllRegions"
            }
        }
    }
    PROCESS 
    {
        foreach ($Instance in $InstanceId){
            $Parameters         = @{InstanceId  = $Instance}
            if ($Region)          {$Parameters.add('Region',$Region)}
            $InstanceStartInfo  = (Get-EC2Instance @Parameters).Instances
            $InstanceStartStatus= $InstanceStartInfo.State.Name.Value
            $InstanceStatus     = $InstanceStartStatus
            $InstanceStartType  = $InstanceStartInfo.InstanceType.Value
            If ($InstanceStartType -eq $InstanceType) {
                Write-Warning "Instance $Instance is already of instance type $InstanceType, skipping"
            } else {
                if ($InstanceStatus -ne "stopped") {Stop-CMEC2InstanceWait -InstanceId $Instance -Region $Region -NoCheck}
                Write-Verbose "Editing Instance Type"
                Edit-EC2InstanceAttribute @Parameters -InstanceType $InstanceType
                if ($InstanceStartStatus -eq "running") 
                {
                    Write-Verbose "Starting Instance"
                    if ($DomainName)
                    {
                        $StartInstance  = Start-CMInstance @Parameters -DomainName $DomainName
                        $InstanceStatus = $StartInstance.CurrentState
                        $Hostname       = $StartInstance.Hostname
                    }
                    else {
                        $StartInstance = Start-EC2Instance @Parameters
                        $InstanceStatus = $StartInstance.CurrentState.Name.Value
                    }
                }
                $OutputProperties = @{
                    InstanceID    = $Instance
                    Status        = $InstanceStatus
                    InstanceType  = $InstanceType
                }
                if ($HostName) {
                    $OutputProperties.Add('Hostname', $HostName)
                }
                $OutputObject     = New-Object -TypeName PSObject -Property $OutputProperties
                Write-Output      $OutputObject
            }
        }
    }
    END{}
}
Function Connect-RemoteDesktop       {
<#   
.SYNOPSIS   
Function to connect an RDP session without the password prompt
    
.DESCRIPTION 
This function provides the functionality to start an RDP session without having to type in the password
	
.PARAMETER ComputerName
This can be a single computername or an array of computers to which RDP session will be opened

.PARAMETER User
The user name that will be used to authenticate

.PARAMETER Password
The password that will be used to authenticate

.PARAMETER Credential
The PowerShell credential object that will be used to authenticate against the remote system

.PARAMETER Admin
Sets the /admin switch on the mstsc command: Connects you to the session for administering a server

.PARAMETER MultiMon
Sets the /multimon switch on the mstsc command: Configures the Remote Desktop Services session monitor layout to be identical to the current client-side configuration 

.PARAMETER FullScreen
Sets the /f switch on the mstsc command: Starts Remote Desktop in full-screen mode

.PARAMETER Public
Sets the /public switch on the mstsc command: Runs Remote Desktop in public mode

.PARAMETER Width
Sets the /w:<width> parameter on the mstsc command: Specifies the width of the Remote Desktop window

.PARAMETER Height
Sets the /h:<height> parameter on the mstsc command: Specifies the height of the Remote Desktop window

.NOTES   
Name:        Connect-RemoteDesktop
Author:      Jaap Brasser
DateUpdated: 2016-10-28
Version:     1.2.5
Blog:        http://www.jaapbrasser.com

.LINK
http://www.jaapbrasser.com

.EXAMPLE   
. .\Connect-RemoteDesktop.ps1
    
Description 
-----------     
This command dot sources the script to ensure the Connect-Mstsc function is available in your current PowerShell session

.EXAMPLE   
Connect-RemoteDesktop -ComputerName server01 -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force)

Description 
-----------     
A remote desktop session to server01 will be created using the credentials of contoso\jaapbrasser

.EXAMPLE
Connect-RemoteDesktop server01,server02 contoso\jaapbrasser (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force)

Description 
-----------     
Two RDP sessions to server01 and server02 will be created using the credentials of contoso\jaapbrasser

.EXAMPLE   
server01,server02 | Connect-RemoteDesktop -User contoso\jaapbrasser -Password supersecretpw -Width 1280 -Height 720

Description 
-----------     
Two RDP sessions to server01 and server02 will be created using the credentials of contoso\jaapbrasser and both session will be at a resolution of 1280x720.

.EXAMPLE   
server01,server02 | Connect-Mstsc -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Wait

Description 
-----------     
RDP sessions to server01 will be created, once the mstsc process is closed the session next session is opened to server02. Using the credentials of contoso\jaapbrasser and both session will be at a resolution of 1280x720.

.EXAMPLE   
Connect-Mstsc -ComputerName server01:3389 -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Admin -MultiMon

Description 
-----------     
A RDP session to server01 at port 3389 will be created using the credentials of contoso\jaapbrasser and the /admin and /multimon switches will be set for mstsc

.EXAMPLE   
Connect-Mstsc -ComputerName server01:3389 -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Public

Description 
-----------     
A RDP session to server01 at port 3389 will be created using the credentials of contoso\jaapbrasser and the /public switches will be set for mstsc

.EXAMPLE
Connect-Mstsc -ComputerName 192.168.1.10 -Credential $Cred

Description 
-----------     
A RDP session to the system at 192.168.1.10 will be created using the credentials stored in the $cred variable.

.EXAMPLE   
Get-AzureVM | Get-AzureEndPoint -Name 'Remote Desktop' | ForEach-Object { Connect-Mstsc -ComputerName ($_.Vip,$_.Port -join ':') -User contoso\jaapbrasser -Password (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) }

Description 
-----------     
A RDP session is started for each Azure Virtual Machine with the user contoso\jaapbrasser and password supersecretpw

.EXAMPLE
PowerShell.exe -Command "& {. .\Connect-Mstsc.ps1; Connect-Mstsc server01 contoso\jaapbrasser (ConvertTo-SecureString 'supersecretpw' -AsPlainText -Force) -Admin}"

Description
-----------
An remote desktop session to server01 will be created using the credentials of contoso\jaapbrasser connecting to the administrative session, this example can be used when scheduling tasks or for batch files.
#>
    [cmdletbinding(SupportsShouldProcess,DefaultParametersetName='UserPassword')]
    param (
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [Alias('CN')]
            [string[]]     $ComputerName,
        [Parameter(ParameterSetName='UserPassword',Mandatory=$true,Position=1)]
        [Alias('U')] 
            [string]       $User,
        [Parameter(ParameterSetName='UserPassword',Mandatory=$true,Position=2)]
        [Alias('P')] 
            [string]       $Password,
        [Parameter(ParameterSetName='Credential',Mandatory=$true,Position=1)]
        [Alias('C')]
            [PSCredential] $Credential,
        [Alias('A')]
            [switch]       $Admin,
        [Alias('MM')]
            [switch]       $MultiMon,
        [Alias('F')]
            [switch]       $FullScreen,
        [Alias('Pu')]
            [switch]       $Public,
        [Alias('W')]
            [int]          $Width,
        [Alias('H')]
            [int]          $Height,
        [Alias('WT')]
            [switch]       $Wait
    )

    begin {
        [string]$MstscArguments = ''
        switch ($true) {
            {$Admin}      {$MstscArguments += '/admin '}
            {$MultiMon}   {$MstscArguments += '/multimon '}
            {$FullScreen} {$MstscArguments += '/f '}
            {$Public}     {$MstscArguments += '/public '}
            {$Width}      {$MstscArguments += "/w:$Width "}
            {$Height}     {$MstscArguments += "/h:$Height "}
        }

        if ($Credential) {
            $User     = $Credential.UserName
            $Password = $Credential.GetNetworkCredential().Password
        }
    }
    process {
        foreach ($Computer in $ComputerName) {
            $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
            $Process = New-Object System.Diagnostics.Process
            
            # Remove the port number for CmdKey otherwise credentials are not entered correctly
            if ($Computer.Contains(':')) {
                $ComputerCmdkey = ($Computer -split ':')[0]
            } else {
                $ComputerCmdkey = $Computer
            }

            $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\cmdkey.exe"
            $ProcessInfo.Arguments   = "/generic:TERMSRV/$ComputerCmdkey /user:$User /pass:$($Password)"
            $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            $Process.StartInfo       = $ProcessInfo
            if ($PSCmdlet.ShouldProcess($ComputerCmdkey,'Adding credentials to store')) {
                [void]$Process.Start()
            }

            $ProcessInfo.FileName    = "$($env:SystemRoot)\system32\mstsc.exe"
            $ProcessInfo.Arguments   = "$MstscArguments /v $Computer"
            $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
            $Process.StartInfo       = $ProcessInfo
            if ($PSCmdlet.ShouldProcess($Computer,'Connecting mstsc')) {
                [void]$Process.Start()
                if ($Wait) {
                    $null = $Process.WaitForExit()
                }       
            }
        }
    }
}
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
Set-Alias cmli   Get-CMEC2Instances
Set-Alias cmni   New-CMEC2Instance