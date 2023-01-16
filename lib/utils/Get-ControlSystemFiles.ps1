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

function Get-ControlSystemFiles {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        [ValidateNotNullOrEmpty()]
        $Device,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $OutputDirectory
    )
    
    begin {
        if ($Device.Series -lt 3) {
            return
        }

        $directories = @("AUTOUPDATELOGS", "CERT", "FIRMWARE", "EDID", "HTML", "NVRAM", "PLOG", "Program01", "Program02", "Program03", "Program04", "Program05", "Program06", "Program07", "Program08", "Program09", "Program10", "SSHBanner", "USER")

        $params = @{
            Device               = $Device.IPAddress
            Secure               = $Device.Secure
            Username             = $Device.Credential.Username
            Password             = $Device.Credential.Password
            CreateLocalDirectory = $true
            Recurse              = $true
        }
    }

    process {
        $directories | ForEach-Object {
            $directory = $_

            if ($Device.Series -ge 4) {
                $directory = $directory.ToLower()
            }

            $localDirectoryPath = Join-Path -Path $OutputDirectory -ChildPath $directory
            
            try {
                Get-FTPDirectory @params -RemoteDirectory $directory -LocalDirectory $localDirectoryPath
            }
            catch {
                continue
            }
        }
    }

    end {}
}