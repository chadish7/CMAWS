# CMAWS
A PowerShell module with AWS helper cmdlets for AWS EC2, SSM and Polly and Route53

## Installation
To install the this module using PowerShell 5 or higher use the following command:

```
Install-Module CMAWS
```

## Cmdlets available are 

### Convert-TextToSpeech
Makes it possible to take one or more text files and run them through Amazon's Polly service to produce output audio files or just play it directly.

### Get-CMEC2Instances
Get all EC2 instances in multiple regions

### New-CMEC2Instance
Easily create new on-demand or spot instances with minimal input while updating DNS hostnames for them in Route 53 as well. Supports Windows and Linux instances.

### Get-CMEC2ImageId
Very quickly gets common the latest Windows and Linux AMIS

### New-CMPassword
A password generator capabible of creating easy passwords like Kaju1543 (Like Office365) with the -Easy Parameter

### Get-EC2WindowsOndemandPrice
Get the EC2 On demand Price for Windows Instances (No SQL). Will expand to Linux and SQL.

### Set-R53Record
Created by Sinisa Mikasinovic - six@mypowershell.space. Creates and Updates Route53 resource records

### Set-CMEC2InstanceType
Stops and Instance, Changes the Instance Type and Starts it again and re-registers the new IP with R53 again if a DNS Name is provided

### Invoke-CMSSMPowerShell
Sends PowerShell script to a SSM Managed Instance waits for execution and brings the result to the console.

### Connect-RemoteDeskop
Connects to Remote Desktop

### Get-CMCFNParameters
Gets Parameters of a CloudFormation template and outputs them as a hashtable to use with New-CFNStack

### Get-AWSCurrentSpend
Gets the Current and Forecasted AWS Spend