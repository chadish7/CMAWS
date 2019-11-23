Function Convert-TextToSpeech        {
<#
.Synopsis
    Converts text files into audio files.
.DESCRIPTION
    Parses the contents of multiple text files and outputs each file to an audio file by using Amazon's Polly service (https://aws.amazon.com/polly/)

.NOTES   
    Name:        Convert-TextToSpeech
    Author:      Chad Miles
    DateUpdated: 2019-08-10
    Version:     1.4.0

.EXAMPLE
   Convert-TextToSpeech input.txt -Voice Joanna

   This will output input.mp3 using Amy voice
.EXAMPLE
   Convert-TextToSpeech *.txt -Voice Amy -OutputFormat ogg -Speed fast
   
   This will convert all the .txt files to .ogg files in Joanna voice speaking in a fast speed.
.EXAMPLE
   Convert-TextToSpeech -String (Get-ClipBoard) -Voice Amy -UseNeuralEngine -PlayOutput
   
   This will grab the Text from the Clipboard, Synthesise it using Amy's Voice with the new Nueral engine and play the output with the default audio player
#>
    [CmdletBinding()]
    [Alias('tts')]
    Param (
        # The Input file(s), wilcards and just pointing to a folder itself work fine, just know that it will suck in what you ever you give it.
        [Parameter(ParameterSetName='Files')]
        [string[]]  $InputFiles, 
        # Format of the output audio in either mp3, ogg or pcm
        [ValidateSet('mp3', 'ogg', 'pcm')]
        [string]    $OutputFormat = "mp3",
        # The voice used, default is Amy (English - UK), for all voices please run Get-POLVoice | select -ExpandProperty Id
        [string]    $Voice = 'Amy',
        # Just process a String not a written file
        [Parameter(ParameterSetName='String')]
        [string[]]  $String,
        # Specify the Base name of the file to output to, without the extention
        [Parameter(ParameterSetName='String')]
        [string]    $OutputFile='Output-'+(New-Guid),
        [switch]    $PlayOutput,
        [ValidateSet('x-fast','x-slow','fast', 'slow', 'medium')]
        [string]    $Speed = 'medium',
        [switch]    $UseNeuralEngine
        
    )
    if ($OutputFormat -eq 'pcm'){$FileExtension = 'wav'}
    else {$FileExtension = $OutputFormat}
    $ErrorActionPreference = 'Stop'
    Write-Verbose 'Validating Voice'
    $VoiceIds   = Get-POLVoice
    if ($VoiceIds.Id.Value -notcontains $Voice) {
        Write-Error "$Voice is not a valid voice, Valid voices are $($VoiceIds.Id.Value)"
    }
    If ($UseNeuralEngine) {
        If (($VoiceIds | Where-Object {$_.Id.Value -eq $Voice}).SupportedEngines -notcontains "neural"){
            Write-Warning "The $Voice voice does not yet support the nueral engine, falling back to standard"
            $UseNeuralEngine = $False
        }
    }
    $Speed          = $Speed.ToLower()
    $PreText        = '<speak><prosody rate="'+$Speed+'">'
    $PostText       = '</prosody><break time="350ms"/></speak>'
    $PollyLimit     = 3000
    $PollyParams    = @{
        TextType      = "ssml"
        VoiceId       = $Voice 
        OutputFormat  = $OutputFormat
    }
    If ($UseNeuralEngine) {$PollyParams.Add("Engine","neural")}
    if ($InputFiles){
        Foreach ($InputFile in Get-ChildItem $InputFiles) {
            $Text          = Get-Content $InputFile
            $LineCount     = 1
            Write-Verbose "Checking $InputFile for long lines"
            Foreach ($Line in $Text){
                $Line = $Line.Replace('&',' and ').Replace('  ',' ')
                If ($Line.Length -ge $PollyLimit-($PreText.Length + $PostText.Length)){
                    $ShortName = $InputFile.Name
                    Write-Warning "$ShortName was skipped as Line $LineCount is longer than $PollyLimit characters, which is the longest we can submit to Polly excluding SSML tags and spaces"
                    $LongLines = $true
                }
                $LineCount++
            }
            If (!$LongLines){
                Write-Verbose "Processing $InputFile"
                $LineCount    = 1
                $BaseName     = $InputFile.BaseName
                $Directory    = $InputFile.Directory
                $OutputFile   = "$Directory\$BaseName.$FileExtension"
                $OutputStream = New-Object System.IO.FileStream $OutputFile, Create
                Try {
                    Foreach ($Line in $Text){
                        $Line         = $Line.Replace('&',' and ').Replace('  ',' ')
                        (Get-POLSpeech -Text $PreText$Line$PostText @PollyParams).AudioStream.CopyTo($OutputStream)
                        $LineCount++
                    }
                } Catch {
                    Write-Host -ForegroundColor Red "Error while processing file"$InputFile.FullName" in Line "$LineCount":" $PSItem.Exception.InnerException
                    $OutputStream.Close()
                    $ProcessingFailed = $true
                } 
                If (!$ProcessingFailed){
                    (Get-POLSpeech -Text '<speak><break time="2s"/></speak>' -TextType ssml -VoiceId $Voice -OutputFormat $OutputFormat).AudioStream.CopyTo($OutputStream)
                    $OutputStream.Close()
                    $OutputProperties = @{
                        OutputFile    = "$BaseName.$FileExtension"
                        InputFile     = $InputFile.Name
                    }
                    New-Object -TypeName PSObject -Property $OutputProperties
                } else {if ( $ProcessingFailed) {Clear-Variable ProcessingFailed}}
            } else {if ($LongLines) {Clear-Variable -Name LongLines}}
        }
    }
    If ($String){
        $LineCount = 0
        foreach ($Line in $String){
            $LineCount++
            $Line   = $Line.Replace('&',' and ').Replace('  ',' ')
            If ($Line.Length -ge $PollyLimit-($PreText.Length + $PostText.Length)){
                Write-Error "String input at line $LineCount longer than $PollyLimit characters, which is the longest we can submit to Polly excluding SSML tags and spaces"
            }
        }
        $NewItem      = New-Item ".\$OutputFile.$FileExtension" -Force
        $OutputFile   = $NewItem.FullName
        $OutputStream = New-Object System.IO.FileStream $OutputFile, Create
        $LineCount = 0
        foreach ($Line in $String){
            $LineCount++
            $Line   = $Line.Replace('&',' and ').Replace('  ',' ')
            Try {
                (Get-POLSpeech -Text $PreText$Line$PostText @PollyParams).AudioStream.CopyTo($OutputStream)
            } Catch {
                Write-Error "Error while processing the String in Line $LineCount : "$_.Exception.InnerException
                $OutputStream.Close()
                $ProcessingFailed = $true
            }
        } 
        If (!$ProcessingFailed){
            $OutputStream.Close()
            $OutputProperties = 
            New-Object -TypeName PSObject -Property @{OutputFile = $NewItem.Name}
        } else {
            if ($ProcessingFailed) {
                Clear-Variable ProcessingFailed
            }
        }
        If ($PlayOutput) {
            & $OutputFile
        }
    }
}
