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

function New-ManifestFromToolboxAddressBook {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AddressBook,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ManifestFile = "manifest.json"
    )

    $manifest = [PSCustomObject]@{
        credentials = @()
        devices     = @()
    }

    $devices = Read-ToolboxAddressBook -AddressBook $AddressBook

    $envFile = Find-Up -FileName ".env"

    if ($envFile) {
        $envVariables = Get-EnvironmentFileVariableList -File $envFile

        $envVariables | ForEach-Object {
            [Environment]::SetEnvironmentVariable($_.Variable, $_.Value)
        }
    }

    # $devices | ForEach-Object {
    #     $device = $_

    #     if (!$device.Username) {
    #         continue
    #     }


    #     $manifest.credentials += [PSCustomObject]@{
    #         id = New-Guid
    #     }
    # }

    $devices | ForEach-Object {
        $device = $_

        $manifest.devices += [PSCustomObject]@{
            address      = $device.Address
            secure       = ($device.Connection -eq "ssh" -or $device.Connection -eq "ssl")
            credentialId = ""
        }
    }

    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $ManifestFile -Force
}

if ((Resolve-Path -Path $MyInvocation.InvocationName).ProviderPath -eq $MyInvocation.MyCommand.Path) {
    try {
        . "$PSScriptRoot\Read-ToolboxAddressBook.ps1"
        . "$PSScriptRoot\Get-EnvironmentFileVariableList.ps1"
        . "$PSScriptRoot\Invoke-Aes256Encrypt.ps1"
        . "$PSScriptRoot\Get-Aes256KeyByteArray.ps1"
        . "$PSScriptRoot\Find-Up.ps1"
    }
    catch {
        throw "Failed to import functions: $_"
    }

    New-ManifestFromToolboxAddressBook @args
}
