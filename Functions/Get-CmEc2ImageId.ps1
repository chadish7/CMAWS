<#
.Synopsis
   Find the latest AWS EC2 AMI based on search critera
.DESCRIPTION
  Outputs only the image ID of the latest AWS EC2 AMI based on option you specficy such as Windows version, SQL verison and SQL Edition or Amazon Linux(2) or Ubuntu

  Supports Core and Container based AMIS and Windows version 2003, 2008, 2008R2, 2012, 2012 R2, 2016, 1709, 1803, 1809 and 2019

  It does this mostly by querying the SSM public paramter store, so the user that is running this must have the AWS PowerShell Module installed and configured as well permission to the  ssm:describeparameter action
  
.EXAMPLE
   PS C:\> (Get-CmEc2ImageId -OsVersion WindowsServer2016 -Region us-east-1).ImageId
   ami-041114ddee4a98333

   Above finds the latest Windows Server 2016 Base AMI in us-east-1 region
.EXAMPLE
   PS C:\> Get-CmEc2ImageId -OsVersion WindowsServer2012R2 -SqlVersion 2008R2
   WARNING: SQL Server 2008 R2 and 2012 only supported on Windows Server 2008R2 and 2012, switching to Windows 2012
   ami-0193fd36c14f87865

   Here SQL server 2008R2 is not supported on Windows 2012 R2 and it has automatically changed the OS to the latest one that supports this SQL version
.EXAMPLE
    PS C:\> Get-CmEc2ImageId -OsVersion 2019 -Core -Containers -Region us-east-1
    ami-0f3d4a916972fd1ac

    Here we specify we want Windows Server 2019 Core edition with Containers in the us-east-1 region
.EXAMPLE
    PS C:\> New-EC2Instance -Region us-east-1 -Subnet subnet-97654567890 -ImageId (Get-CmEc2ImageId -OsVersion WindowsServer2016 -Region us-east-1).ImageId -KeyPair MyKeyPair

    This launches an instance in the us-east-1 region getting the latest AMI for Windows Serve 2016 in that region.
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   ImageId (String)
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
    [CmdletBinding(DefaultParameterSetName = 'Base')]
    Param(
        [Parameter(Position = 0)]
        #[ValidatePattern('(WindowsServer)?(180(3|9)|1709|20(03|(08|12)(R2)?|16|19))|Ubuntu1(6|8)\.04|AmazonLinux2?')]
        [ValidateSet(
            "WindowsServer21H1", 
            "WindowsServer20H2", 
            "WindowsServer2004", 
            "WindowsServer1909", 
            "WindowsServer1903", 
            "WindowsServer2019",
            "WindowsServer2016",
            "WindowsServer2012R2",
            "WindowsServer2012",
            "21H1",
            "20H2",
            "2004",
            "1909",
            "1903",
            "2019",
            "2016",
            "2012R2",
            "2012",
            "Ubuntu16.04",
            "Ubuntu18.04",
            "AmazonLinux",
            "AmazonLinux2",
            "AL2",
            "AL1",
            "AL",
            "AmazonLinux2NetCore",
            "AL2NetCore",
            "UbuntuNetCore",
            "EcsAmazonLinux",
            "EcsAmazonLinux2",
            "EcswindowsServer2016",
            "EcswindowsServer2019"
        )]
        [string] $OsVersion = "2019",
        [ValidateSet("2019", "2017", "2016", "2014", "2012")]
        [string] $SqlVersion,

        [ValidateSet("Express", "Web", "Standard", "Enterprise")]
        [string] $SqlEdition = "Standard",

        [switch] $Core,
        [switch] $Containers,
        [switch] $NoSwitching,
        
        [ValidateScript( { @((Get-AWSRegion).Region) })]
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
        [string] $Language = "English",
        [switch] $ImageIdOnly
    )
    $ErrorActionPreference = "Stop"

    if ($ShowValidOS) {return $SupportedOSs}

    If ($OsVersion -like "WindowsServer*") {
        $OsVersion = $OsVersion.Substring(13)
    } 
    If ($OsVersion -match '(190(3|9)|20(12(R2)?|1(6|9)|04|H2))|21H(1|2)') {
        $Base = $True
        $LatestStable = "20H2", "2019"
        if ($OsVersion -match '(190(3|9)|2004)') { $Core = $True }
        if ($Core -and $OsVersion -notmatch '190(3|9)|20(04|12(R2)?|1(6|9)|H2)|21H(1|2)') {
            Write-Warning "Core AMIs only available for Windows Server 2012R2 and later, Switching to Windows Server $($LatestStable[0])"
            $OsVersion = $LatestStable[0]
        }
        if ($Containers) {
            $Base = $False
            if ($OsVersion -notmatch '190(3|9)|20(04|16|19|H2)|21H(1|2)') {
                Write-Warning "Container AMIs only available for Windows Server 2016 and later, Switching to Windows Server $($LatestStable[1])"
                $OsVersion = $LatestStable[1]
            }
        }
        if ($SqlVersion) {
            $Base = $False
            If ($Core -and $OsVersion -ne 2016 -and $SqlVersion ) { Write-Warning "SQL only avaialable on Core Editions of Windows Server 2016, Switching to Full"; $Core = $False }
            If ($Containers) { Write-Warning "SQL AMI not available with Containers, Switching to Non-Containers"; $Containers = $False }
            If ($SqlVersion -eq "2012") { $SqlSp = "_SP4" }
            If ($SqlVersion -eq "2014") { $SqlSp = "_SP3" }
            If ($SqlVersion -eq "2016") { $SqlSp = "_SP2" }
            $SqlVersion = $SqlVersion.ToUpper()
            $SqlEdition = $SqlEdition.Substring(0, 1).ToUpper() + $SqlEdition.Substring(1).ToLower()
            $SqlText = "SQL_" + $SqlVersion + $SqlSp + "_" + $SqlEdition 
            if ($OsVersion -notmatch '201(6|9)' -and $SqlVersion -match '201(7|9)') {
                Write-Warning "SQL Server $SqlVersion only supported on Windows Server 2016 and 2019, switching to Windows $($LatestStable[1])"
                $OSVersion = $($LatestStable[1])
            }
            if ($OsVersion -notmatch '201(2R2|6|9)' -and $SqlVersion -eq "2016") {
                Write-Warning "SQL Server 2016 only supported on Windows Server 2012 R2, 2016 and 2019, switching to Windows $($LatestStable[1])"
                $OSVersion = $($LatestStable[1])
            }
            if ($OsVersion -notmatch '2012' -and $SqlVersion -eq "2014") {
                Write-Warning "SQL Server 2014 only supported on Windows Server 2012 or 2012 R2, switching to Windows 2012 R2"
                $OSVersion = "2012R2"
            }
            if ($OsVersion -ne '2012' -and $SqlVersion -eq '2012') {
                Write-Warning "SQL Server 2012 only supported on Windows Server 2012, switching to Windows 2012"
                $OSVersion = "2012"
            }
        }
        $OSVersion = $OSVersion.ToUpper()
        $Language = $Language.Substring(0, 1).ToUpper() + $Language.Substring(1).ToLower()
    
        $BaseText = "/aws/service/ami-windows-latest/Windows_Server-"

        if ($OsVersion -match '190(3|9)|20(04|H2)') {
            $SearchString = $BaseText + $OsVersion + "-" + $Language + "-Core"
            if ($Base) { $SearchString = $SearchString + "-Base" }
            else { $SearchString = $SearchString + "-ContainersLatest" }
        }
        if ($OsVersion -match '201(6|9)') {
            if ($Core) { $SearchString = $BaseText + $OsVersion + "-" + $Language + "-Core" }
            else { $SearchString = $BaseText + $OsVersion + "-" + $Language + "-Full" }
            if ($Base) { $SearchString = $SearchString + "-Base" }
            elseif ($Containers) {
                if ($OsVersion -eq '2016') { $SearchString = $SearchString + "-Containers" }
                if ($OsVersion -eq '2019') { $SearchString = $SearchString + "-ContainersLatest" }
            }
            else { $SearchString = $SearchString + "-" + $SqlText }
        }
        if ($OsVersion -eq "2012R2") {
            if ($Base) {
                if ($Core) { $SearchString = $BaseText + "2012-R2_RTM-" + $Language + "-64Bit-Core" }
                else { $SearchString = $BaseText + "2012-R2_RTM-" + $Language + "-64Bit-Base" }
            }
           
            else { $SearchString = $BaseText + "2012-R2_RTM-" + $Language + "-64Bit-" + $SqlText }
        }

        if ($OsVersion -eq "2012") {
            if ($Base) { $SearchString = $BaseText + "2012-RTM-" + $Language + "-64Bit-Base" }
            else { $SearchString = $BaseText + "2012-RTM-" + $Language + "-64Bit-" + $SqlText }
        }
    }
    If ($OsVersion -like "Ubuntu*") {
        $FilterParam = @{Filter = @{Name = "name"; Values = "ubuntu/images/hvm-ssd/ubuntu-bionic-$($OsVersion.TrimStart("Ubuntu"))-amd64-server*" } }
        if ($Region) { $FilterParam.Add('Region', $Region) }
        $Images = Get-Ec2Image @FilterParam
    }
    If ("AmazonLinux2", "AL2" -contains $OsVersion) {
        $SearchString = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
    }
    If ("AmazonLinux", "AL1", "AL" -contains $OsVersion) {
        $SearchString = "/aws/service/ami-amazon-linux-latest/amzn-ami-hvm-x86_64-gp2"
    }
    If ("AmazonLinux2NetCore", "AL2NetCore" -contains $OsVersion) {
        $FilterParam = @{Filter = @{ Name = "name"; Values = "amzn2-x86_64-*DOTNET*" } }
        if ($Region) { $FilterParam.Add('Region', $Region) }
        $Images = Get-Ec2Image @FilterParam 
    }
    If ($OsVersion -eq "UbuntuNetCore") {
        $FilterParam = @{Filter = @{ Name = "name"; Values = "ubuntu*amd64*dotnetcore*" } }
        if ($Region) { $FilterParam.Add('Region', $Region) }
        $Images = Get-Ec2Image @FilterParam
    }
    If ($OsVersion -eq "EcsAmazonLinux") {
        $SearchString = "/aws/service/ecs/optimized-ami/amazon-linux/recommended/image_id"
    }
    If ($OsVersion -eq "EcsAmazonLinux2") {
        $SearchString = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
    }
    If ($OsVersion -eq "EcsWindowsServer2019") {
        $ImageId = (Get-SSMParameter -Name /aws/service/ami-windows-latest/Windows_Server-2019-English-Full-ECS_Optimized | Select-Object -ExpandProperty "Value" | ConvertFrom-Json).image_id
    }
    If ($OsVersion -eq "EcsWindowsServer2016") {
        $SearchString = "/aws/service/ami-windows-latest/Windows_Server-2016-English-Full-ECS_Optimized/image_id"
    }
    
    If ($SearchString) {
        $SSMParameters = @{Name = $SearchString }
        if ($Region) { $SSMParameters.Add('Region', $Region) }
        Try { 
            $ImageId = (Get-SSMParameter @SSMParameters).Value
        }
        Catch { 
            Write-Error "AMI Not Found" 
        }
    }
    If ($ImageIdOnly) {
        If ($Images) {
            ($Images | Where-Object Name -NotMatch "beanstalk" | Sort-Object Name | Select-Object -Last 1).ImageId
        }
        If ($ImageId) { 
            $ImageId
        }
    }
    else {
        If ($Images) {
            $Images | Where-Object Name -NotMatch "beanstalk" | Sort-Object Name | Select-Object -Last 1 
        }
        If ($ImageId) {
            $ImageParams = @{ImageId = $ImageId }
            if ($Region) { $ImageParams.Add('Region', $Region) }
            Get-EC2Image @ImageParams
        }
    }
}