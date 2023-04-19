## v1.3.3
- Added support for AmazonLinux2023 to `Get-CmEc2ImageId` and `Get-CmEc2Instances` parameter `OsVersion`.
- Fixed `Get-CmEc2ImageId` bad error handling for searching SSM Parameters.

## v1.3.2
- `New-CMEC2Instance` Now selects arm64/x86_64 automatically based on instance type.
- Updated `Get-CmEc2ImageId` and `New-CmEc2Instance` to support arm64 for Amazon Linux and Ubuntu

## v1.3.1
- Most cmdlets support the `ProfileName` parameter now to select a AWS CLI/SDK Credential profile.

## v1.3.0
`Get-CmEc2ImageId` and `New-CmEc2Instance`:       
- Updated OS versions for Ubuntu, Windows, and AmazonLinux
- Added Support for SQL 2022 on Windows
- Removed unsupported OS versions
- **BREAKING** Removed ECS Optimized OS Versions, moved to EcsOptimized switch parameter
- **BREAKING** Removed Short Windows Server names in `OSVersion` to remove ambiguity"
- Added Support for ECS Optimized to AmazonLinux 2 and 2022+