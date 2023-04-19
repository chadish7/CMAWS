#Requires -Module FXPSYaml
function Get-CMCFNParameters {
  [OutputType([String])]
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [String] $Template,
    [ValidateSet("YAML", "JSON")]
    [String] $Format = "YAML"
  )
  if ($Format -eq "YAML"){
      if (-not (Get-Command ConvertFrom-Yaml)){
      Write-error "ConvertFrom-Yaml not found, please make sure the FXPSYaml module is installed"
    }
  }
  $Text = @('$Parameters = @(')
  Try   { $Parameters = [PSCustomObject]($Template | ConvertFrom-Yaml).Parameters }
  Catch { $Parameters = [PSCustomObject]($Template | ConvertFrom-Json).Parameters }
  If ($Parameters){
    foreach ($Param in ($Parameters | Get-Member | Where-Object MemberType -eq "NoteProperty").Name) { 
      $Text+='    @{ParameterKey="'+$Param+'"; ParameterValue='+$(
        if ($Parameters.$Param.Default) {'"'+$Parameters.$Param.Default+'"'}
        elseif ($Parameters.$Param.Type -eq "AWS::EC2::SecurityGroup::Id"){if ($SGId)     {'$SGId'}      else {'""'}}
        elseif ($Parameters.$Param.Type -eq "List<AWS::EC2::Subnet::Id>") {if ($SubnetIds){'$SubnetIds'} else {'""'}}
        elseif ($Parameters.$Param.Type -eq "AWS::EC2::Subnet::Id")       {if ($SubnetId) {'$SubnetId'}  else {'""'}}
        elseif ($Parameters.$Param.Type -eq "AWS::EC2::VPC::Id")          {if ($VpcId)    {'$VpcId'}     else {'""'}}
        elseif ($Parameters.$Param.Type -eq "AWS::EC2::Image::Id")        {if ($AMI)      {'$AMI'}       else {'""'}}
        elseif ($Parameters.$Param.Type -eq "AWS::EC2::KeyPair::KeyName") {if ($KeyPair)  {'$KeyPair'}   else {'""'}}
        else {'""'}
      )+'}'
    }
  }
  $Text+=')'
  $Text | Out-String
}