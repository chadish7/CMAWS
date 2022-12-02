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
    ImageName             : WINDOWS_2012R2_BASE
    ImageID               : ami-40003a26
    KeyName               : MyKeyPair

.EXAMPLE
    C:\> New-CMEC2Instance -InstanceType t2.micro -Region us-east-1 -Name MyInstance -DomainName mydomain.com -SpotRequest

    InstanceID            : i-1234567890abcdef
    Region                : us-east-1
    Name                  : MyInstance
    Hostname              : MyInstance.Mydomain.com
    InstanceType          : t2-micro
    ImageName             : WINDOWS_2016_BASE
    ImageID               : ami-40003a26
    KeyName               : MyKeyPair

.EXAMPLE
    C:\> New-CMEC2Instance -InstanceType m3.medium -Region us-east-1 -Name TestInstance -DomainName mydomain.com -RootVolumeSize 50 -SecondaryVolumeSize 100
    
    InstanceID            : i-1234567890abcdef
    Region                : us-east-1
    Name                  : TestInstance
    Hostname              : TestInstance.Mydomain.com
    InstanceType          : m3.medium
    ImageName             : WINDOWS_2016_BASE
    ImageID               : ami-58a1a73e
    KeyName               : MyKeyPair

#>
    [CmdletBinding( 
        SupportsShouldProcess   = $true,
        DefaultParameterSetName = 'SearchBaseIds')]
    Param (
        [ValidateScript({@((Get-AWSRegion).Region)})]
        [string] $Region,
        [Parameter(Mandatory=$true)]
        [Alias("Type")] 
        [String] $InstanceType,
        # Applies this name tag to the instance after creation, if -DomainName is specified as well then registers a DNS CNAME for your instance using this name
        [string] $Name,
        # E.g mydomain.com. Must be used with -Name, then a DNS CNAME is registered, provided it is a Route53 hosted zone and you have rights.
        [string] $DomainName,
        # Version of Windows e.g. 2012R2 or 2016. Default is 2016
        [ValidateSet(
            "WindowsServer22H2", 
            "WindowsServer21H2",  
            "WindowsServer2022",
            "WindowsServer2019",
            "WindowsServer2016",
            "WindowsServer2012R2",
            "22H2",
            "21H2",
            "2022",
            "2019",
            "2016",
            "2012R2",
            "Ubuntu18.04",
            "Ubuntu20.04",
            "Ubuntu22.04",
            "AmazonLinux2",
            "AmazonLinux2NetCore",
            "UbuntuNetCore",
            "EcsAmazonLinux2",
            "EcswindowsServer2016",
            "EcswindowsServer2019"
        )]
        [string] $OsVersion = "2019",

        [Parameter(ParameterSetName='SearchSqlIds')]
        [ValidateSet("2017","2016","2014","2012")]
        [string] $SqlVersion,

        [Parameter(ParameterSetName='SearchSqlIds')]
        [ValidateSet("Express", "Web","Standard","Enterprise")]
        [string] $SqlEdition = "Standard",

        [switch] $Core,
        # Instance Profile (with IAM Role) to attach to new Instance
        [string] $InstanceProfile,
        # Path to User data file , using Your My Documents folder as a root
        [string] $UserData,
        #Specify an AMI id like ami-2b8c8452
        [Parameter(ValueFromPipeline       =$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName               ='ImageId',
            Mandatory                      =$true)]
        [ValidatePattern("^ami-([\da-f]{8}|[\da-f]{17})$")]
        [string] $ImageId,
        # The name of the Security Group, not the Security Group ID. The Function will get the ID. If none is specified the default Security Group is used.
        [string] $SecurityGroupName,
        # Switch to specify that a Spot instance should be created instead of On Demand. Bid price will be automatically calculated based on current bid price plus a markup percentage of which the default is 1.
        [switch] $SpotInstance,
        # The Name of the EC2 KeyPair to use when creating the instance
        [string] $KeyName,
        # The ID of the VPC you wish to use, if not specified, the default one is used.
        [ValidatePattern("^vpc-([\da-f]{8}|[\da-f]{17})$")]
        [string] $VpcId,
        # Last letter of the Availability Zone like a, b, c, d or e, if none specified, a random one is used
        [string] $AZSuffix,
        # The Subnet in which to launch the Instance(s). Overrides VpcId if and AZsuffix parameters if specified. If not specified then a random subnet is chosen in the default VPC.
        [ValidatePattern("^subnet-([\da-f]{8}|[\da-f]{17})$")]
        [string] $SubNetId,
        [ValidateRange(1,15)]
        [Int]    $NetworkInterfaces = 1,
        [Int]    $Count = 1,
        # Specifies the Root EBS volume size in GB
        [Int]    $RootVolumeSize,
        # Speciies the Secondary EBS volume size if there is one present in the AMI. If not it will create a new volume and attach it.
        [Int]    $SecondaryVolumeSize,
        # Default is to Keep the secondary volume on instance terminations, but set this switch to kill it
        [switch] $TerminateSecondaryVolume,
        # The AWS CLI/SDK Credential Profile to use
        [string] $ProfileName


    )
    BEGIN 
    {
        $ErrorActionPreference    = "Stop"
        if ($AZSuffix){
            if (-not $Region) {$Region = (Get-DefaultAWSRegion).Region}
            if (-not $Region) {try {$Region = (Get-EC2InstanceMetadata -Category Region).SystemName} catch {}}
            $AvailabilityZone      = $Region+$AZSuffix
        }        
        $Architecture = (Get-EC2InstanceType -InstanceType $InstanceType).ProcessorInfo.SupportedArchitectures[0]
        Write-Verbose "Got Architecture $Architecture"
        $GeneralParams = @{}
        If ($Region)     { $GeneralParams.Region      = $Region}
        If ($ProfileName){ $GeneralParams.ProfileName = $ProfileName}
    }
    Process {
        if ($SqlVersion) {
            if ($InstanceType -like "t*.*" -and $SqlEdition -ne "Express") {
                Write-Error "Non Express editions of SQL Server are not permited to run on T2/T3 instance types"
            }
        }
        
        if (-not $ImageId) {
            Write-Verbose  "Getting Current AMI for Selected OS $OsVersion and Architecture $Architecture"
            $ImageParam  = @{
                OsVersion    = $OsVersion
                Architecture = $Architecture
            }
            If ($Core)       { $ImageParam.Core        = $true}
            If ($SqlVersion) { $ImageParam.SqlVersion  = $SqlVersion}
            If ($SqlEdition) { $ImageParam.SqlEdition  = $SqlEdition}
            $ImageId = ($Image = Get-CMEC2ImageId @ImageParam @GeneralParams).ImageId
        } else {
            $ImageParam      = @{ImageId = $ImageId}
            If ($Region)     { $ImageParam.Region      = $Region}
            If ($ProfileName){ $ImageParam.ProfileName = $ProfileName}
            try {$Image  = Get-EC2Image @ImageParam @GeneralParams}
            Catch {}
        }
        if (-not $ImageId -or -not $Image) { Write-Error "Could not find an image with Search criteria in region $Region"}
        Write-Verbose "Got image $ImageId ($($Image.Name))"
        if (-not $Keyname) {
            Write-Verbose  "Getting first KeyPair for Region"
            $KeyName  = (Get-EC2KeyPair @GeneralParams)[0].KeyName
    }
        if (-not $KeyName)    {Write-Error "No EC2 Key Pairs found in region $Region, please create one"}
        If ($UserData)    {$UserData64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($UserData))}
        If (-not $SubNetId) { 
            If (-not $VpcId)   
            {
                Write-Verbose   "Getting default VPC"
                $VpcId  = (Get-EC2Vpc @GeneralParams| Where-Object {$_.IsDefault -eq $true}).VpcId
            }
            If (-not $VpcId)   { Write-Error "Could not find default VPC in region $Region, Please specify either a VPC or a Subnet Id" }
            Write-Verbose       "Getting Subnet for name $AvailabilityZone"
            $SubNets = Get-EC2Subnet @GeneralParams -Filter @{Name='vpc-id';Values=$VpcId}
            If ($AvailabilityZone) {$SubNetId = ( $SubNets | Where-Object {$_.AvailabilityZone -eq $AvailabilityZone})[0].SubnetId}
            else {$SubNetId = ($SubNets | Where-Object {$_.VpcId -eq $VPCid})[(Get-Random -Maximum $($SubNets.Count-1))].SubnetId}
        } Else {
            $VpcId = (Get-EC2Subnet @GeneralParams -SubnetId $SubNetId).VpcId
        }
        If (-not $VpcId) {Write-Error "Could not determine VPC, check you have a default VPC in the region and if SubnetId is specified, make sure it is valid"}
    
        If ($SecurityGroupName)  {
            Write-Verbose       "finding Security Group named $SecurityGroupName"
            $SecurityGroupId   = (Get-EC2SecurityGroup @GeneralParams | Where-Object {$_.GroupName -eq $SecurityGroupName -and $_.VpcId -eq $VpcId})[0].GroupId
            If (!$SecurityGroupId) {Write-Warning "Security Group with $SecurityGroupName cannot be found, using default"}
        } 
        if (-not $SecurityGroupId) {
            Write-Verbose       "Getting default Security Group for VPC $VpcId"
            $SecurityGroupId   = (Get-EC2SecurityGroup @GeneralParams | Where-Object {$_.GroupName -eq "default" -and $_.VpcId -eq $VPCId})[0].GroupId
            If (!$SecurityGroupId) {Write-Error "No Default security group found in $VpcId"}
        }
        If ($RootVolumeSize){
            $BDMs = $Image.BlockDeviceMappings
            ($BDMs | Where-Object {$_.DeviceName -eq $Image.RootDeviceName}).EBS.VolumeSize = $RootVolumeSize
        }
        If ($SecondaryVolumeSize){
            If (-not $BDMs) {$BDMs = $Image.BlockDeviceMappings}
            Try {
                ($BDMs | Where-Object {$_.DeviceName -ne $Image.RootDeviceName -and $null -ne $_.Ebs})[0].EBS.VolumeSize = $SecondaryVolumeSize
            } Catch {
                $SecondaryBdm = [Amazon.EC2.Model.BlockDeviceMapping]@{
                    DeviceName = if ($Image.Platform -eq "Windows"){"xvdb"}
                        Else {"/dev/sdb"}
                    Ebs = [Amazon.EC2.Model.EbsBlockDevice]@{
                        VolumeSize          = $SecondaryVolumeSize
                        DeleteOnTermination = ($TerminateSecondaryVolume -ne $false)
                    }
                }
                $BDMs += $SecondaryBdm
            }
        }
        $InstanceParams    = @{
            MinCount         = $Count
            MaxCount         = $Count
            InstanceType     = $InstanceType
            SecurityGroupId  = $SecurityGroupId
            ImageId          = $ImageId
            SubnetId         = $SubNetId
            KeyName          = $KeyName
        }
            
        if ($Name) {
            $InstanceParams.TagSpecification = @(
                [Amazon.EC2.Model.TagSpecification]@{
                    ResourceType = "instance"
                    Tags         = @(@{ Key="Name"; Value=$Name })    },
                [Amazon.EC2.Model.TagSpecification]@{
                    ResourceType = "volume"
                    Tags         = @(@{ Key="Name"; Value=$Name })    }
            )
        }
        If ($SpotInstance)    { $InstanceParams.InstanceMarketOption = @{MarketType ="Spot"} }
        If ($UserData64)      { $InstanceParams.UserData             = $UserData64 }
        If ($InstanceProfile) { $InstanceParams.InstanceProfile_Name = $InstanceProfile }
        If ($BDMs)            { $InstanceParams.BlockDeviceMapping   = $BDMs }
        
        $InstanceId       = ($NewInstance = (New-EC2Instance @InstanceParams @GeneralParams).Instances).InstanceId
        
        if ($Name -and $Count -eq 1) {
            If ($DomainName) {
                $DNSParams        = @{InstanceId    = $InstanceId}
                if($Region)        {$DNSParams.Add('Region',$Region)}
                $SetDns           = Set-CmEc2DnsName @DNSParams -DomainName $DomainName -InstanceName $Name
                $HostName         = $SetDns.Hostname
            }
        } else {
            $HostName = $RunningInstance.PublicIPAddress
        }
        [PSCustomObject]@{
            InstanceId      = $InstanceId
            Region          = $NewInstance.Placement.AvailabilityZone.Trimend('abcdef')
            Name            = $Name
            Hostname        = $HostName
            InstanceType    = $InstanceType
            ImageName       = $Image.Name
            ImageId         = $ImageId
            KeyName         = $KeyName
            InstanceProfile = $InstanceProfile
        }
    }
}