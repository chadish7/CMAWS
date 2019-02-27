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
        [ValidateScript({@((Get-AWSRegion).Region)})]
        [string] $Region,
        [Parameter(Mandatory=$true)]
        [ValidateScript({(Get-CmEc2InstanceTypes)})]
        [String] $InstanceType,
        # Applies this name tag to the instance after creation, if -DomainName is specified as well then registers a DNS CNAME for your instance using this name
        [string] $Name,
        # If -Name is also specified then a DNS CNAME is registered in this domain, provided the domain is hosted in R53 and you have rights to do so.
        [string] $DomainName,
        # Version of Windows e.g. 2012R2 or 2016. Default is 2012R2
        [ValidateSet("WindowsServer2019",
            "WindowsServer1809", 
            "WindowsServer1803",
            "WindowsServer1709",
            "WindowsServer2016",
            "WindowsServer2012R2",
            "WindowsServer2012",
            "WindowsServer2008R2",
            "WindowsServer2008",
            "WindowsServer2003",
            "2019",
            "1809",
            "1803",
            "1709",
            "2016",
            "2012R2",
            "2012",
            "2008R2",
            "2008",
            "2003",
            "AmazonLinux",
            "Ubuntu18.04",
            "Ubuntu16.04",
            "AmazonLinux2")]
        [string] $OsVersion = 2016,

        [Parameter(ParameterSetName='SearchBaseIds')]
        [switch] $Base=$true,

        [Parameter(ParameterSetName='SearchSqlIds')]
        [ValidateSet("2017","2016","2014","2012","2008R2","2008","2005")]
        [string] $SqlVersion,

        [Parameter(ParameterSetName='SearchSqlIds')]
        [ValidateSet("Express", "Web","Standard","Enterprise")]
        [string] $SqlEdition = "Standard",

        [switch] $Core,

        # Instance Profile (with IAM Role) to attach to new Instance
        [string] $InstanceProfile,
        # Path to User data file , using Your My Documents folder as a root
        [string] $UserData,
        # What Percrentage to add to the lowest Spot Price to ensure instance's longevity
        [int]    $MarkUp     = 1,
        #Specify an AMI id like ami-2b8c8452
        [Parameter(ValueFromPipeline       =$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName               ='ImageId',
            Mandatory                      =$true)]
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
        [string] $AZSuffix,
        [string] $SubNetId,
        [ValidateRange(1,15)]
        [Int]    $NetworkInerfaces = 1

    )
    <#DynamicParam 
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
    }#>
    BEGIN 
    {
        $ErrorActionPreference    = "Stop"
        if ($AZSuffix){
            if (-not $Region) {$Region = (Get-DefaultAWSRegion).Region}
            if (-not $Region) {try {$Region = (Get-EC2InstanceMetadata -Category Region).SystemName} catch {}}
            $AvailabilityZone      = $Region+$AZSuffix
        }
        
    }
    Process {
        if ($SqlVersion) 
        {
            Clear-Variable Base
            if ($InstanceType -like "t2.*" -and $SqlEdition -ne "Express") {Write-Error "Non Express editions of SQL Server are not permited to run on t2 instance types"}
        }
        [int]$Count               = 1 
        
        Write-Verbose          "Geting On Demand Instance Pricing"
        $OndemandPrice         = Get-EC2WindowsOndemandPrice -InstanceType $InstanceType -Region $Region
        
        if (!$ImageID) 
        {
            Write-Verbose       "Getting Current AMI for Selected OS"
            $ImageParam      = @{OsVersion = $OsVersion}
            If ($Core)       {$ImageParam.Add('Core',$true)}
            If ($Region)     {$ImageParam.Add('Region',$Region)}
            If ($SqlVersion) {$ImageParam.Add('SqlVersion',$SqlVersion)}
            If ($SqlEdition) {$ImageParam.Add('SqlEdition',$SqlEdition)}
            $ImageID           = Get-CMEC2ImageId @ImageParam
        }
        if (!$ImageID) {         Write-Error "Could not find an image with Search criteria in region $Region"}
        if (!$Keyname) 
        {
            Write-Verbose       "Getting first KeyPair for Region"
            $KeyName           = (Get-EC2KeyPair -Region $Region)[0].KeyName
        }
        if (!$KeyName)          {Write-Error "No EC2 Key Pairs found in region $Region, please create one"}
        If ($UserData)          {$UserData64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($UserData))}
        If (!$SubNetId){ 
            If (!$VpcId)   
            {
                Write-Verbose       "Getting default VPC"
                $VpcId             = (Get-EC2Vpc -Region $Region| Where {$_.IsDefault -eq $true}).VpcId
            }
            If (!$VpcId)   {         Write-Error "Could not find default VPC in region $Region, Please specify either a VPC or a Subnet Id"}
            Write-Verbose       "Getting Subnet for name $AvailabilityZone"
            $SubNets = Get-EC2Subnet -Region $Region -Filter @{Name='vpc-id';Values=$VpcId}
            If ($AvailabilityZone) {$SubNetId = ( $SubNets | where {$_.AvailabilityZone -eq $AvailabilityZone})[0].SubnetId}
            else {$SubNetId = ($SubNets | where {$_.VpcId -eq $VPCid})[(Get-Random -Maximum $($SubNets.Count-1))].SubnetId}
        } Else {
            $VpcId = (Get-EC2Subnet -Region $Region -SubnetId $SubNetId).VpcId
        }
        If (!$VpcId) {Write-Error "Could not determine VPC, check you have a default VPC in the region and if SubnetId is specified, make sure it is valid"}
    
        If ($SecurityGroupName)  {
            Write-Verbose       "Getting Security Group for name $SecurityGroupName"
            $SecurityGroupId   = (Get-EC2SecurityGroup -Region $Region | where {$_.GroupName -eq $SecurityGroupName -and $_.VpcId -eq $VpcId})[0].GroupId
            If (!$SecurityGroupId) {Write-Error "Security Group with $SecurityGroupName cannot be found"}
        } 
        else {
            Write-Verbose       "Getting Security Group for VPC $VpcId"
            $SecurityGroupId   = (Get-EC2SecurityGroup -Region $Region | where {$_.GroupName -eq "default" -and $_.VpcId -eq $VPCId})[0].GroupId
        }
        If (!$SecurityGroupId)  {
            Write-Error "Could not find a Security Group with the name $SecurityGroupName in region $Region"
        }
    
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
            
        if ($Name) {
            $tag1 = @{ Key="Name"; Value=$Name }
            $Tags = @()
            $tagspec1 = New-Object -Type Amazon.EC2.Model.TagSpecification
            $tagspec1.ResourceType = "instance"
            $tagspec1.Tags.Add($tag1)
            $Tags+=$tagspec1
            $tagspec2 = New-Object -Type Amazon.EC2.Model.TagSpecification
            $tagspec2.ResourceType = "volume"
            $tagspec2.Tags.Add($tag1)
            $Tags+=$tagspec2
            $Params.Add("TagSpecification",$Tags)
        }
        If ($SpotInstance) {
            $InstanceMarketOption = @{
                MarketType ="Spot"
                <#SpotOptions = @{
                    InstanceInterruptionBehavior = "stop"
                    SpotInstanceType = "persistent"
                }#>
            }
            $Params.Add("InstanceMarketOption",$InstanceMarketOption)
        }
            
            If ($UserData64)      {$Params.Add("UserData",$UserData64)}
            If ($InstanceProfile) {$Params.Add("InstanceProfile_Name",$InstanceProfile)}
            $InstanceId       = (New-EC2Instance @Params).Instances.InstanceId
            
        if ($Name) {
            If ($DomainName) {
                $DNSParams        = @{InstanceId    = $InstanceId}
                if($Region)        {$DNSParams.Add('Region',$Region)}
                $SetDns           = Set-CmEc2DnsName @DNSParams -DomainName $DomainName -InstanceName $Name
                $HostName         = $SetDns.Hostname
            }
        } else {
            $HostName = $RunningInstance.PublicIPAddress
        }
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
