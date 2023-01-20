<#
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2022 Norgate AV Solutions Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

function Invoke-Aes256Encrypt {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Data,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Key
    )

    begin {}

    process {
        try {
            $iv = [System.Byte[]]::new(16)
            $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
            $rng.GetBytes($iv)

            $aes = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
            $aes.Key = Get-Aes256KeyHash -Key $Key
            $aes.IV = $iv

            $unencrypted = [System.Text.Encoding]::UTF8.GetBytes($Data)

            $encryptor = $aes.CreateEncryptor()
            $encrypted = $encryptor.TransformFinalBlock($unencrypted, 0, $unencrypted.Length)

            [byte[]] $fullData = $aes.IV + $encrypted
            $result = [System.Convert]::ToBase64String($fullData)
        }
        catch {
            Write-Error $_.Exception.GetBaseException().Message
        }
        finally {
            $aes.Dispose()
            $rng.Dispose()
        }
    }

    end {
        if ($result) {
            return $result
        }
    }
}

if ((Resolve-Path -Path $MyInvocation.InvocationName).ProviderPath -eq $MyInvocation.MyCommand.Path) {
    try {
        . "$PSScriptRoot\Get-Aes256KeyHash.ps1"
        . "$PSScriptRoot\Get-Sha256Hash.ps1"
    }
    catch {
        throw "Failed to import functions: $_"
    }

    Invoke-Aes256Encrypt @args
}
