# CMAWS
A PowerShell module with AWS helper cmdlets for AWS EC2, SSM and Polly and Route53

## Installation
To install the this module using PowerShell 5 or higher use the following command:

```PowerShell
Install-Module CMAWS
```

## Cmdlets 

### Convert-TextToSpeech
Converts one or more text files to Speech (audio files) with Amazon's Polly service.

### Get-CMEC2Instances
Get all EC2 instances in multiple regions
```PowerShell
C:\> Get-CmEc2Instances -Regions us-east-1, us-west-2, us-east-2 | Format-Table

Name      State   InstanceType InstanceId          AZ         RunningTime PublicIpAddress Platform
----      -----   ------------ ----------          --         ----------- --------------- --------
Windows   stopped c5.2xlarge   i-087b4273de55193f1 us-east-1b                             Windows
Test      stopped t3a.micro    i-0acd74cb1365bb1f7 us-east-1a
Test-USW2 stopped t3a.micro    i-0b52ec5c66dbf5baa us-west-2a
AL2       stopped t3a.micro    i-045450f9c91fc6c33 us-west-2b
```

### New-CMEC2Instance
Easily create new on-demand or spot instances with minimal input while updating DNS hostnames for them in Route53. Supports Windows, AmazonLinux, and Ubuntu instances.
```Powershell
C:\> New-CMEC2Instance -InstanceType t2.micro -Region us-east-1 -Name MyInstance -DomainName mydomain.com -OSVersion AmazonLinux2023

    InstanceID            : i-1234567890abcdef
    Region                : us-east-1
    Name                  : MyInstance
    Hostname              : MyInstance.mydomain.com
    InstanceType          : t2-micro
    ImageName             : al2022-ami-2022.0.20230118.3-kernel-5.15-x86_64
    ImageID               : ami-40003a26
    KeyName               : MyKeyPair

```

### Get-CMEC2ImageId
Gets the latest Windows, AmazonLinux, and Ubuntu Amazon Machine Images (AMIs)

#### Windows
```PowerShell
PS C:\> (Get-CmEc2ImageId -OsVersion WindowsServer2022 -Region us-east-1).ImageId
    ami-041114ddee4a98333
```
#### AmazonLinux
```PowerShell
PS C:\> (Get-CmEc2ImageId -OsVersion AmazonLinux2023 -Region us-east-1).ImageId
    ami-06e46074ae430fba6
```

### New-CMPassword
A password generator capabible of creating easy passwords like Kaju1543 (Like Office365) with the `-Easy` Parameter

### Get-EC2WindowsOndemandPrice
Get the EC2 On demand Price for Windows Instances. Will expand to Linux and SQL.

### Set-R53Record
Inspired by Sinisa Mikasinovic - six@mypowershell.space. Creates and Updates Route53 resource records

### Set-CMEC2InstanceType
Stops an EC2 Instance, Changes the Instance Type and Starts it again and re-registers the new IP with the Route 53 Resource Record again if a DNS Name is provided

### Invoke-CMSSMPowerShell
Sends PowerShell script to a SSM Managed Instance waits for execution and brings the result to the console.

### Connect-RemoteDeskop
Connects to Remote Desktop

### Get-CMCFNParameters
Gets Parameters of a CloudFormation template and outputs them as a hashtable to use with the `Parameters` parameter in the AWS PowerShell Tools cmdlet `New-CFNStack`

### Get-AWSCurrentSpend
Gets the Current and Forecasted AWS Spend