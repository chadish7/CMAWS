Function New-CmPassword {
    <#
    .Synopsis
       Generates random passwords
    .DESCRIPTION
       Generates Random passwords and outputs as text and to Clipboard or just to clipboard
    .EXAMPLE
       PS> New-CMPassword -Easy
       Kobi2858
    .EXAMPLE
       PS> New-CMPassword
       N42v9AjCWF1J
    .EXAMPLE
       PS> New-CMPassword -ClipOnly 
       PS>
       Password is only put in clipboard and not displayed on screen.
    .EXAMPLE
       PS> $pass = New-CMPassword
       PS> Set-ADAccountPassword DOMAIN\USERNAME -NewPassword (ConvertTo-SecureString ($pass) -AsPlainText -Force)
       PS> Write-Output "Account password set to $pass"

       This will set an AD account's password to a randomly generated password and copy that password to the clipboard
    #>
    [CmdletBinding()]
    [Alias('np')]
    [OutputType([String])]
    Param
    (
        #Creates easy readable and rememberable password like Office 365's password generator
        [Switch]   $Easy, 
        #Enables the use of special characters, like !^&*(%$#)-=_+
        [Switch]   $Specials,
        #Doesn't output the password as text but rather only copies it to Clipboard
        [Switch]   $ClipOnly,
        #Specifies the length of the password. This parameter is ignored when you use the -Easy switch
        [Parameter(Position = 0)]
        [int]      $Length = 12,
        #Specifies the ammount of passwords to generate, only the last one will be left in the clipboard
        [int]      $Count = 1
    )
    for ($c = 0 ; $c -lt $Count ; $c++) {
        if ($easy -Eq $true) {
            $digits = 48..57
            $UpperConsonants = 66..68 + 70..72 + 74..78 + 80..84 + 86..90
            $LowerConsonants = 98..100 + 102..104 + 106..110 + 112..116 + 118..122
            $LowerVowels = 97, 101, 105, 111, 117

            $first = [char](get-random -count 1 -InputObject $UpperConsonants)
            $second = [char](get-random -count 1 -InputObject $LowerVowels)
            $third = [char](get-random -count 1 -InputObject $LowerConsonants)
            $fourth = [char](get-random -count 1 -InputObject $LowerVowels)
            $numbers = $null
            for ($i = 0 ; $i -lt 4; $i++) {
                $numbers += [char](get-random -count 1 -InputObject $digits)
            }
            $password = ($first + $second + $third + $fourth + $numbers)
        }
        Else {
            $digits = 48..57
            $letters = 65..90 + 97..122
            $specialchar = 33..47 + 58..64 + 91..96 + 123..126
            $password = $null
            for ($i = 0 ; $i -lt $Length ; $i++) {
                If ($Specials -eq $true) { $password += [char](get-random -count 1 -InputObject ($digits + $letters + $specialchar)) }
                Else { $password += [char](get-random -count 1 -InputObject ($digits + $letters)) }
            }
        }
        $password | Set-Clipboard
        If (!$ClipOnly) { $password }
    }
}
