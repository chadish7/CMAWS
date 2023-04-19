<#
.Synopsis
    Find the latest AWS EC2 AMI based on search critera
.DESCRIPTION
    Outputs only the image ID of the latest AWS EC2 AMI based on option you specficy such as Windows version, SQL verison and SQL Edition or Amazon Linux(2) or Ubuntu

    Supports Core and Container based AMIS and Windows version 2012 R2, 2016, 1709, 1803, 1809 and 2019

    It does this mostly by querying the SSM public paramter store, so the user that is running this must have the AWS PowerShell Module installed and configured as well permission to the  ssm:describeparameter action
    
.EXAMPLE
    PS C:\> (Get-CmEc2ImageId -OsVersion WindowsServer2022 -Region us-east-1).ImageId
    ami-041114ddee4a98333

    Above finds the latest Windows Server 2016 Base AMI in us-east-1 region
.EXAMPLE
    PS C:\> Get-CmEc2ImageId -OsVersion 2019 -Core -Containers -Region us-east-1
    ami-0f3d4a916972fd1ac

    Here we specify we want Windows Server 2019 Core edition with Containers in the us-east-1 region
.EXAMPLE
    PS C:\> New-EC2Instance -Region us-east-1 -Subnet subnet-97654567890 -ImageId (Get-CmEc2ImageId -OsVersion WindowsServer2016 -Region us-east-1).ImageId -KeyPair MyKeyPair

    This launches an instance in the us-east-1 region getting the latest AMI for Windows Serve 2016 in that region.
.OUTPUTS
    Image (String)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to the CMAWS Module
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>
Function Get-CmEc2ImageId {
    [OutputType([Amazon.Route53.Model.ChangeInfo])]
    [CmdletBinding(DefaultParameterSetName = 'Windows')]
    Param(
        [Parameter(Position = 0)]
        #[ValidatePattern('WindowsServer2(0(1(2R2|6|9)|22)|[12]H2)|Ubuntu(18|2[02])\.04|AmazonLinux2(02\d)?')]
        [ValidateSet(
            "WindowsServer22H2", 
            "WindowsServer21H2", 
            "WindowsServer2022",
            "WindowsServer2019",
            "WindowsServer2016",
            "WindowsServer2012R2",
            "Ubuntu22.04",
            "Ubuntu20.04",
            "Ubuntu18.04",
            "AmazonLinux2",
            "AmazonLinux2022",
            "AmazonLinux2023",
            "AmazonLinux2025",
            "AmazonLinux2027",
            "AmazonLinux2NetCore"
        )]
        [string] $OsVersion = "WindowsServer2022",
        [ValidateSet("2022","2019", "2017", "2016", "2014")]
        [Parameter(ParameterSetName='SQL')]
        [string] $SqlVersion,

        [Parameter(ParameterSetName='SQL')]
        [ValidateSet("Express", "Web", "Standard", "Enterprise")]
        [string] $SqlEdition = "Standard",

        [switch] $Core,
        [Parameter(ParameterSetName='Containers')]
        [switch] $Containers,
        [Parameter(ParameterSetName='Ecs')]
        [switch] $EcsOptimized,
        
        [ValidateScript( { @((Get-AWSRegion).Region) })]
        [string] $Region,
        # The CPU Architecture to use. Available values, arm64 or x86_64.
        [ValidateSet("arm64","x86_64")]
        [string] $Architecture = "x86_64",
        [ValidateSet(
            "Chinese_Traditional", "Chinese_Simplified", "Czech",
            "Dutch", "English", "French", "German", "Hungarian",
            "Korean", "Japanese", "Polish", "Portuguese_Brazil",
            "Russian", "Spanish", "Swedish", "Turkish")]
        [string] $Language = "English",
        # Return only the Image Id as a string.
        [switch] $ImageIdOnly,
        # The AWS CLI/ SDK Credential Profile to use
        [string] $ProfileName
    )
    $ErrorActionPreference = "Stop"

    $GeneralParams = @{}
    If ($Region)     { $GeneralParams.Region      = $Region}
    If ($ProfileName){ $GeneralParams.ProfileName = $ProfileName}
    
    If ($OsVersion -like "WindowsServer*") {     # Windows Image Logic
        $WindowsVersion = $OsVersion.Substring(13)
        if ($Architecture -ne "x86_64") { Write-Error "Windows Server only available on x86_64" }
        $Base         = $True
        $LatestStable = "22H2", "2022"
        if ($WindowsVersion -match '2[12]H2') { $Core = $True }
        if ($Containers) {
            if ($WindowsVersion -match '2012R2') {
                Write-Warning "Container AMIs only available for Windows Server 2016 and later, Switching to Windows Server $($LatestStable[1])"
                $WindowsVersion = $LatestStable[1]
            }
        }
        if ($SqlVersion) {
            If ($Core -and $WindowsVersion -ne 2016 -and $SqlVersion ) { Write-Warning "SQL only avaialable on Core Editions of Windows Server 2016, Switching to Full"; $Core = $False }
            If ($SqlVersion -eq "2014") { $SqlSp = "_SP3" }
            If ($SqlVersion -eq "2016") { $SqlSp = "_SP3" }
            $SqlVersion = $SqlVersion.ToUpper()
            $SqlEdition = $SqlEdition.Substring(0, 1).ToUpper() + $SqlEdition.Substring(1).ToLower()
            $SqlText    = "-SQL_" + $SqlVersion + $SqlSp + "_" + $SqlEdition
            if ($WindowsVersion -notmatch '201[69]' -and $SqlVersion -match '201[79]') {
                Write-Warning "SQL Server $SqlVersion only supported on Windows Server 2016 and 2019, switching to Windows 2019"
                $WindowsVersion = "2019"
            }
            if ($WindowsVersion -NE '2022' -and $SqlVersion -EQ '2022') {
                Write-Warning "SQL Server $SqlVersion only supported on Windows Server 2022, switching to Windows 2022"
                $WindowsVersion = "2022"
            }
            if ($WindowsVersion -notmatch '201(2R2|[69])' -and $SqlVersion -eq "2016") {
                Write-Warning "SQL Server 2016 only supported on Windows Server 2012 R2, 2016 and 2019, switching to Windows 2019"
                $WindowsVersion = "2019"
            }
            if ($WindowsVersion -NE '2012R2' -and $SqlVersion -eq "2014") {
                Write-Warning "SQL Server 2014 only supported on Windows Server 2012 or 2012 R2, switching to Windows 2012 R2"
                $WindowsVersion = "2012R2"
            }
        }
        if ($EcsOptimized -or $SqlVersion -or $Containers) { $Base = $False }
        $WindowsVersion = $WindowsVersion.ToUpper()
        $Language  = $Language.Substring(0, 1).ToUpper() + $Language.Substring(1).ToLower()
    
        $BaseText  = "/aws/service/ami-windows-latest/Windows_Server-"

        if ($WindowsVersion -match '2[12]H2') {
            $SearchString = $BaseText + $WindowsVersion + "-" + $Language + "-Core"
            if ($Base) { $SearchString += "-Base" }
            else { $SearchString += "-ContainersLatest" }
        }
        if ($WindowsVersion -match '20(16|19|22)') {
            if ($Core) { $SearchString = $BaseText + $WindowsVersion + "-" + $Language + "-Core" }
            else { $SearchString = $BaseText + $WindowsVersion + "-" + $Language + "-Full" }
            if ($Base) { $SearchString += "-Base" }
            elseif ($SqlVersion) { $SearchString += $SqlText}
            elseif ($Containers) {
                if ($WindowsVersion -eq '2016') { $SearchString += "-Containers" }
                if ($WindowsVersion -match '20(19|22)') { $SearchString += "-ContainersLatest" }
            }
            elseif ($EcsOptimized) {
                $SearchString += '-ECS_Optimized/image_id'
            }
        }
        if ($WindowsVersion -eq "2012R2") {
            if ($Base) {
                if ($Core) { $SearchString = $BaseText + "2012-R2_RTM-" + $Language + "-64Bit-Core" }
                else { $SearchString = $BaseText + "2012-R2_RTM-" + $Language + "-64Bit-Base" }
            }
            elseif($SqlVersion) { $SearchString = $BaseText + "2012-R2_RTM-" + $Language + "-64Bit" + $SqlText }
        }
    }
    If ($OsVersion -match "^Ubuntu(18|2[02])\.04$") {
        if ($Architecture -EQ 'x86_64'){ $UbuntuArch = 'amd64' }
        else{$UbuntuArch = $Architecture}
        $Filter = @{Name = "name"; Values = "ubuntu/images/hvm-ssd/ubuntu-*-$($OsVersion.TrimStart("Ubuntu"))-$UbuntuArch-server-20??????" }
        $Images = Get-Ec2Image @GeneralParams -Filter $Filter
    }
    If ($OsVersion -match "^AmazonLinux2(02\d)?$") {
        $BaseText = "/aws/service/ami-amazon-linux-latest"
        $ALVersion = $OsVersion.TrimStart('AmazonLinux') 
        if     ($ALVersion -eq "2")    {$SearchString = "$BaseText/amzn2-ami-hvm-$Architecture-gp2"} 
        elseif ($ALVersion -match "202\d") {$SearchString = "$BaseText/al$ALVersion-ami-kernel-default-$Architecture"} 
        if ($EcsOptimized){
            $SearchString = "/aws/service/ecs/optimized-ami/amazon-linux-$ALVersion/"
            if ($Architecture -EQ "x86_64") { $SearchString += "recommended/image_id" }
            else { $SearchString += "$Architecture/recommended/image_id" }
        }
    }
    If ($OsVersion -eq "AmazonLinux2NetCore") {
        $Images = Get-Ec2Image @GeneralParams -Filter @{ Name = "name"; Values = "amzn2-$Architecture-*DOTNET*" }
    }
    If ($SearchString) {
        Try   { 
            $ImageId = (Get-SSMParameter @GeneralParams -Name $SearchString ).Value
            Write-Verbose "Got ImageId $ImageId"
        } 
        Catch { Write-Error "AMI Not Found with error: $($Error[0])" }
    }
    if ($Images) { $Image = $Images | Where-Object Name -NotMatch "beanstalk" | Sort-Object Name | Select-Object -Last 1 }
    If ($ImageIdOnly) {
        If ($Image)   { return $Image.ImageId }
        If ($ImageId) { return $ImageId }
    }
    If ($Image)   { return $Image }
    If ($ImageId) { return Get-EC2Image @GeneralParams -ImageId $ImageId }
}