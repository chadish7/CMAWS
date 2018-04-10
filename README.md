# CMAWS
A PowerShell module with AWS helper cmdlets for EC2, SSM and Polly and Route53

## Installation
To install the this module using PowerShell 5 or higher use the following command:

Install-Module CMAWS


## Cmdlets available are 

### Convert-TextToSpeech
Makes it possible to take one or more text files and run them through Amazon's Polly service to produce output audio files.

### Get-CMInstances
Get all EC2 instances in all or selected regions

### New-CMEC2Instance
Easily create new on-demand or spot instances with minimal input. Optimized for Windows instances at the moment.

### New-CMPassword
A password generator capabible of creating easy passwords like Kaju1543 (Like Office365)

### New-CMEasyPassword
An alias for New-CMPassword -Easy

### Get-EC2WindowsOndemandPrice
Get the EC2 On demand Price for Windows Instances (No SQL). Will expand to Linux and SQL.

### Set-R53Record
Created by Sinisa Mikasinovic - six@mypowershell.space. Creates and Updates Route53 resource records





