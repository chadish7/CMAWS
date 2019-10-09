<#If ($PSVersionTable.PSVersion -ge [version]"6.0.0") {
    $AWSPS="AWSPowerShell.NetCore"
    if (-not (Get-Module CMAWS,$AWSPS,ClipboardText)){Import-Module CMAWS,$AWSPS, ClipboardText} 
} Else {$AWSPS="AWSPowerShell"}
Function Get-CMIsenCred ($Account, $Role) {
    Try {
        Get-IsengardTempCred -AWSAccountID $Account -IAMAssumeRole $Role
    }
    Catch {
        Set-MidwayCookies
        Get-IsengardTempCred -AWSAccountID $Account -IAMAssumeRole $Role
    }
}  
Get-CMIsenCred -Account 320440645088 -Role Admin | Set-AwsCredential -StoreAs AdminIsenGard
Initialize-AWSDefaultConfiguration -ProfileName chadmile -Region $LaunchRegion
#>
Import-Module AWS.Tools.Route53 -EA SilentlyContinue
Function Set-CMEC2Parameters {
    #Set Variables here that are personal to your environment
    Param (
        [switch]$ListInstances
    )
    Import-Module AWS.Tools.Route53 -EA SilentlyContinue
    # FICTITIOUS DEFAULTS, PLEASE REPLACE and then delete this line !!!!!
    $MyDocs                = [Environment]::GetFolderPath("MyDocuments")
    $global:ActiveRegions  = "us-east-1","eu-west-1"
    $global:LaunchRegion   = $global:ActiveRegions[0]
    $global:DnsSuffix      = "mydomain.com"
    $global:PemFile        = $MyDocs + "\PEMFILES\keypair.pem"
    $global:LaunchParams = @{
        Region             = $LaunchRegion
        UserData           = Get-Content $MyDocs"\scripts\AWS\Instance-Userdata.ps1" -Raw
        InstanceProfile    = "allow-ssm"
        SecurityGroup      = "Default"
        DomainName         = $global:DnsSuffix
        KeyName            = "aws"
    }
    $global:SsmParams = @{
        OutputS3BucketName = "my-ssm-log-bucket"
        OutputS3KeyPrefix  = "ssm/"
        OutputS3Region     = "us-east-1"
    }
    $global:Instances = Get-CMEC2Instances -Region $ActiveRegions | Where {$_.State -NotLike "term*" -and $_.State -NotLike "shutt*"} 
    if ($ListInstances) {$Instances | Sort Name | Format-Table Name, State, AZ, InstanceType, PublicIpAddress, InstanceId}
    if ($Global:InstanceStuff) {Clear-Variable InstanceStuff}
}; Set-CMEC2Parameters -ListInstances; 
Function Select-Instance     {
    [CmdletBinding()]
    Param ()
    DynamicParam {
        $Names                 = $Instances.Name
        $ParameterName         = 'InstanceNames'
        $ParamDictionary       = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $ParamAttrib           = New-Object System.Management.Automation.ParameterAttribute
        $ParamAttrib.Mandatory = 1
        $ParamAttrib.Position  = 0
        $AttribColl            = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $AttribColl.Add($ParamAttrib)
        $AttribColl.Add((New-Object  System.Management.Automation.ValidateSetAttribute($Names)))
        $RuntimeParam          = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string[]], $AttribColl)
        $RuntimeParamDic       = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $RuntimeParamDic.Add($ParameterName,  $RuntimeParam)
        return  $RuntimeParamDic
    }
    BEGIN {
        $InstanceNames = $PSBoundParameters.InstanceNames
    }
    PROCESS {
        $Global:SelectedInstance = @()
        foreach ($I in $InstanceNames) {$global:SelectedInstance += $Instances | Where {$_.Name -eq $I -and !($_.State -like "term*" -or $_.State -like "shutti*")}}
        If ($SelectedInstance) {
            $Global:InstanceParams = @{
                InstanceId = $SelectedInstance.InstanceId
                Region     = foreach ($AZ in $SelectedInstance.AZ) {
                    $AZ.Substring(0, ($AZ.Length - 1))
                    break
                }
            }
            $Global:DnsParams = $Global:InstanceParams + @{DomainName = $DnsSuffix}
            $Global:ResourceParams = @{
                Resource = $SelectedInstance.InstanceId
                Region   = foreach ($AZ in $SelectedInstance.AZ) {
                    $AZ.Substring(0, ($AZ.Length - 1))
                    break
                }
            }
        }
    }
}  

Select-Instance Linux

if ($InstanceStuff -and $False) {
    #Things in this section will not run with the script so you must run then individually from the ISE

    New-CmEC2Instance      @LaunchParams -Name Test -InstanceType m4.large -OsVersion 2016 | Ft -AutoSize ; Set-CMEC2Parameters
    Start-CmEc2Instance    @DnsParams
    (Remove-EC2Instance    @InstanceParams -Force).CurrentState.Name.Value
    (Stop-EC2Instance      @InstanceParams).CurrentState.Name.Value
    Set-CMEC2InstanceType  @DnsParams -InstanceType t3.small
    New-EC2Tag             @ResourceParams -Tag @{Key = "auto-stop"; Value = "yes"}, @{Key = "auto-delete"; Value = "no"} 
    
    $NewImage = New-EC2Image @InstanceParams -Name $SelectedInstance.Name
    (Get-EC2Image -ImageId $NewImage ).State.Value
    Unregister-EC2Image -imageId $NewImage
    
    While (!$Password) {$Password = Get-EC2PasswordData @InstanceParams -Pem $PemFile ; if (!$Password) {Start-Sleep 15}}; $Password|scb 
    Connect-RemoteDesktop  -ComputerName $SelectedInstance.PublicIPAddress -Password $Password -User Administrator; clv Password
    
    # Update the AWS PowerShell Module
    Update-Module AWS.Tools.*

    foreach ($R in $global:DefaultRegions) {
        $TagParams = @{Region = $R ; ResourceId = (Get-EC2Instance -Region $R).Instances.InstanceId}
        New-EC2Tag -Tag @{Key = "auto-stop"; Value = "yes"}, @{Key = "auto-delete"; Value = "no"} @TagParams
    }

    # Assign an EIP to the Primary interface of Selected instance, creating a new EIP if there are no spare ones available
    $NICs = (Get-EC2NetworkInterface -Region $InstanceParams.Region | Where {$_.Attachment.InstanceId -eq $InstanceParams.InstanceId}).NetworkInterfaceId
    Foreach ($Nic in $Nics) {
        $Addresses = @((Get-EC2Address -Region $InstanceParams.Region | Where AssociationId -eq $null).AllocationId)
        If (!$Addresses) {$Addresses = @((New-EC2Address -Region $InstanceParams.Region).AllocationId)}
    Register-EC2Address -Region $InstanceParams.Region -NetworkInterfaceId $Nic -AllocationId $Addresses[0]
    }
    #Remove the above EIP once it's not needed
    Remove-EC2Address -AllocationId $Addresses[0] -Region $InstanceParams.Region

    # Add an ENI to Selected Instance
    Add-EC2NetworkInterface -NetworkInterfaceId (New-EC2NetworkInterface -SubnetId (Get-EC2Instance @InstanceParams).Instances.SubnetId -Region $InstanceParams.Region).NetworkInterfaceId -InstanceId $InstanceParams.InstanceId -DeviceIndex 1
    
    Stop-CmEc2InstanceWait @InstanceParams ; Start-CMInstance @DnsParams
    
    # Console Output from Test Instance:
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-EC2ConsoleOutput @InstanceParams).Output))
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-ClipBoard -raw)))
    #  Screen Shot from Test Instance: 
    [IO.File]::WriteAllBytes((ni ~\screen.jpg -F), ([Convert]::FromBase64String((Get-EC2ConsoleScreenshot @InstanceParams).ImageData))); ~\screen.jpg
       
    Get-WKSWorkspace | Where UserName -eq "chadm" | Stop-WKSWorkspace
    Get-WKSWorkspace | Where UserName -eq "chadm" | Start-WKSWorkspace

    $EniId = (New-EC2NetworkInterface -SubnetId (Get-EC2Instance @InstanceParams).instances.subnetid).NetworkInterfaceId
    Add-EC2NetworkInterface   @InstanceParams -NetworkInterfaceId $EniId -DeviceIndex 2
    Edit-EC2InstanceAttribute @InstanceParams -EnaSupport $false
    Edit-EC2InstanceAttribute @InstanceParams -SriovNetSupport "simple"
    (Get-EC2InstanceAttribute @InstanceParams -Attribute instanceInitiatedShutdownBehavior).SriovNetSupport
    Edit-EC2InstanceAttribute @InstanceParams -InstanceInitiatedShutdownBehavior stop
    
    Edit-EC2InstanceAttribute @InstanceParams -InstanceType r3.large

    (Get-EC2InstanceStatus    @InstanceParams) | ConvertTo-Json
}
If ($SSM_Stuff) {

    Select-Instance Test

    $DocumentName = Get-SSMDocumentList | Where Name -match "AWS-UpdateEC2" | Select -ExpandProperty Name 
    (ConvertFrom-Json (Get-SSMDocument -Name $DocumentName).Content).Parameters | fl
    
     # Run Automation Document
    $CommandId = (Start-SSMAutomationExecution -DocumentName $DocumentName -Parameters @{
        SourceAmiId = "ami-1234567890abcdef"
        IamInstanceProfileName ="allow-ssm"
        AutomationAssumeRole = "arn:aws:iam::123456789012:role/ssm-role"
        InstanceType = "t3.small"
    })
    
    # Check Automation Document running     
    (Get-SSMAutomationExecution -AutomationExecutionId $CommandId).StepExecutions | Select StepName, Action, StepStatus, ExecutionStartTime
        
    $CommandId = (Send-SSMCommand -DocumentName $DocumentName @InstanceParams @SSMParams -Parameters @{
        commands = @'
        whoami
'@
    }).CommandId
    # Update EC2Config
    $CommandId = (Send-SSMCommand -DocumentName AWS-UpdateEC2Config @InstanceParams @SSMParams).CommandId

    # Update SSM Agent
    $CommandId = (Send-SSMCommand -DocumentName AWS-UpdateSSMAgent @InstanceParams @SSMParams).CommandId

    # VSS Snapshot
    $CommandId = (Send-SSMCommand -DocumentName AWSEC2-CreateVssSnapshot @InstanceParams @SSMParams).CommandId

    # Apply Patch Baseline
    $CommandId = (Send-SSMCommand -DocumentName AWS-RunPatchBaseline @InstanceParams @SSMParams -Parameter @{Operation = "Scan"}).CommandId
    (Get-SSMCommandInvocationDetail -CommandId $CommandId @InstanceParams -PluginName PatchWindows).StandardOutputContent

    While ((Get-SSMCommandInvocationDetail -CommandId $CommandId @InstanceParams).Status.Value -eq "InProgress"){Start-Sleep -Seconds 1}
    (Get-SSMCommandInvocationDetail -CommandId $CommandId @InstanceParams).StandardOutputContent
    

    Get-SSMInstanceInformation -R $InstanceParams.Region | Where InstanceId -eq $InstanceParams.InstanceId | fl # Select  Name, InstanceId, PingStatus, AgentVersion

    (Get-SSMInventory| Where Id -eq $SelectedInstance.InstanceId).Data | Show-Object
   
    # Check SSM Document Status
    (Get-SSMCommandInvocation -CommandId $CommandId @InstanceParams).Status.Value
    
    # Send PowerShell
    (Invoke-CMSSMPowerShell   @InstanceParams -Command {
            Get-Content "C:\Programdata\Amazon\EC2-Windows\Launch\Log\UserdataExecution.log"
        }).Output

    (Get-SSMInventoryEntriesList @InstanceParams -TypeName "AWS:Application").Entries | scb
}
If ($Volumes_Stuff) {
    
    Select-Instance Test

    foreach ($reg in $global:DefaultRegions) {
        $resparam = @{Region = $reg; ResourceId = (Get-EC2Volume -Region $reg).volumeId}
        New-EC2Tag -Tag @{Key = "auto-stop"; Value = "yes"}, @{Key = "auto-delete"; Value = "no"} @resparam
    }

    $DrivesToAdd = 5
    $letters = @()  
    for ([byte]$c = [char]'f'; $c -le [char]'z'; $c++) { 
        $letters += [char]$c 
    }
    for ($i = 0; $i -lt $DrivesToAdd; $i++) {
        $VolumeId = (New-EC2Volume -Region $InstanceParams.Region -AvailabilityZone $SelectedInstance.AZ -Size ($i + 1) -VolumeType standard).VolumeId
        While ((Get-EC2Volume -VolumeId $VolumeId -Region $InstanceParams.Region).Status -ne "available") {Start-Sleep 1}
        (Add-EC2Volume          @InstanceParams -VolumeId $VolumeId -Device "xvd$($letters[$i])").State.Value
    }

    $VolumeId = (New-EC2Volume -Region $InstanceParams.Region -AvailabilityZone $SelectedInstance.AZ -Size 500 -VolumeType st1).VolumeId
    While ((Get-EC2Volume -VolumeId $VolumeId -Region $InstanceParams.Region).Status -ne "available") {Start-Sleep 1}
    (Add-EC2Volume  @InstanceParams -VolumeId $VolumeId -Device "xvdf").State.Value

    Edit-EC2Volume -VolumeId $VolumeId -Size 120

    Remove-EC2Volume -VolumeId $VolumeId
    Select-Instance Test

    $VolumeId = "vol-00e5709b58e17ad1b"

    Select-Instance Test
    $VolumeId = (Get-EC2InstanceAttribute -Attribute blockDeviceMapping @InstanceParams).BlockDeviceMappings.ebs.VolumeId
    (Stop-EC2Instance        @InstanceParams).CurrentState.Name.Value
    While ((Get-EC2Instance  @InstanceParams).Instances.State.Name.Value -ne "stopped"){Sleep 1}
    (Dismount-EC2Volume      -VolumeId $VolumeId @InstanceParams).State.Value
    While (((Get-EC2Volume   -VolumeId $VolumeId).State.Value) -ne "available"){ Sleep 1 }
    Select-Instance Test2
    (Add-EC2Volume            @InstanceParams -VolumeId $VolumeId -Device "xvdf").State.Value


    (Dismount-EC2Volume      -VolumeId $VolumeId @InstanceParams).State.Value
    While (((Get-EC2Volume   -VolumeId $VolumeId).State.Value) -ne "available"){ Sleep 1 }
    Select-Instance Test
    (Add-EC2Volume           @InstanceParams -VolumeId $VolumeId -Device "/dev/sda1").State.Value
    Start-CMEC2Instance      @DnsParams
    
    Dismount-EC2Volume -VolumeId $VolumeId
    Add-EC2Volume          @InstanceParams -VolumeId $VolumeId -Device "/dev/sda1"

    # Delete all unattached volumes in region
    Foreach ($VolumeId in  (Get-EC2Volume -Region $InstanceParams.Region | Where State -EQ "available").VolumeId) {
        Remove-EC2Volume -VolumeId $VolumeId -Region $InstanceParams.Region -Force
    }

    #Detach and Delete all non root volumes for selected instance
    Foreach ($VolumeId in  (Get-EC2Volume -Region $InstanceParams.Region | Where {$_.Attachments.InstanceId -EQ $InstanceParams.InstanceId -and $_.Attachments.Device -ne "/dev/sda1"}).VolumeId) {
        (Dismount-EC2Volume -VolumeId $VolumeId -Region $InstanceParams.Region -Force).State.Value
        While ((Get-EC2Volume -VolumeId $VolumeId -Region $InstanceParams.Region).Status -ne "available") {sleep 1}
        Remove-EC2Volume -VolumeId $VolumeId -Region $InstanceParams.Region
    }
}