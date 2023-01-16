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

function Get-TouchPanelProgramInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Device
    )

    begin {
        $files = @(
            [PSCustomObject] @{
                Name       = "~.LocalInfo.vtpage"
                Pattern    = '[\s\S]+VTZ=(?<vtz>[\s\S]+)[\s\S]+Date=(?<date>[\w \d,:]+)[\s\S]+Panel=(?<panel>[\w \d-]+)[\s\S]+Rackname=(?<rackname>[\w \d-]+)[\s\S]+Orientation=(?<orientation>[\w]+)[\s\S]+VTpro-e=(?<vtpro>[\w\d\.]+)[\s\S]+Database=(?<database>[\d\w\.]+)[\s\S]+'
                Properties = @{
                    ProgramFile = "vtz"
                    CompiledOn  = "date"
                    Panel       = "panel"
                    Rackname    = "rackname"
                    Orientation = "orientation"
                    VTpro       = "vtpro"
                    Database    = "database"
                }
            },
            [PSCustomObject] @{
                Name       = "~.Manifest.dat"
                Pattern    = '(?<path>[a-zA-Z]:[\\\w \d\.-]+\.vtz)'
                Properties = @{
                    SourceFile = "path"
                }
            }
        )
    }

    process {
        $programInfo = [PSCustomObject] @{
            Device      = $Device.Hostname
            SourceFile  = ""
            ProgramFile = "No Program"
            CompiledOn  = ""
            Panel       = ""
            Rackname    = ""
            Orientation = ""
            VTpro       = ""
            Database    = ""
        }

        try {
            $localTempFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $Device.Hostname

            $params = @{
                Device               = $Device.IPAddress
                Secure               = $Device.Secure
                Username             = $Device.Credential.Username
                Password             = $Device.Credential.Password
                RemoteDirectory      = "display"
                LocalDirectory       = $localTempFolder
                CreateLocalDirectory = $true
            }

            Get-FTPDirectory @params

            if (!(Test-Path -Path $localTempFolder)) {
                throw
            }

            $files | ForEach-Object {
                $path = Join-Path -Path $localTempFolder -ChildPath $_.Name
                
                if (!(Test-Path -Path $path)) {
                    throw
                }
                
                $content = Get-Content -Path $path -Raw
                
                $pattern = [regex] $_.Pattern
                $match = $pattern.Match($content)
                
                if (!$match.Success) {
                    throw
                }
                
                foreach ($key in $_.Properties.Keys) {
                    $programInfo.$key = $match.Groups[$_.Properties[$key]].Value.Trim()
                }
            }

            Remove-Item -Path $localTempFolder -Force -Recurse
        }
        catch {
            Write-Error -Message "error: [$($Device.Device)] => $($_.Exception.GetBaseException().Message)"
        }
    }

    end {
        return $programInfo
    }
}