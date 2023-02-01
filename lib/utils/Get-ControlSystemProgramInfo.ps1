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

function Convert-ProgramInfo {

    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        [ValidateNotNullOrEmpty()]
        $Device,

        [Parameter(Mandatory = $true)]
        [string]
        [ValidateNotNullOrEmpty()]
        $ConsoleResponse
    )

    $result = [PSCustomObject] @{
        Device               = $Device.Hostname
        ProgramBootDirectory = ""
        SourceFile           = ""
        ProgramFile          = "No Program"
        SystemName           = ""
        Programmer           = ""
        CompiledOn           = ""
        CompilerRev          = ""
        CrestronDb           = ""
        DeviceDb             = ""
        SymLibRev            = ""
        IoLibRev             = ""
        IopCfgRev            = ""
        SourceEnv            = ""
        TargetRack           = ""
        ConfigRev            = ""
        Include4DotDat       = ""
        FriendlyName         = ""
    }

    $result.ProgramBootDirectory = [Regex]::Match($ConsoleResponse, '(?<=Program Boot Directory\s*:\s*)[\S].+').Value.Trim()
    $result.SourceFile = [Regex]::Match($ConsoleResponse, '(?<=Source File\s*:\s*)[\S].+').Value.Trim()
    $result.ProgramFile = [Regex]::Match($ConsoleResponse, '(?<=Program File\s*:\s*)[\S].+').Value.Trim()
    $result.SystemName = [Regex]::Match($ConsoleResponse, '(?<=System Name\s*:\s*)[\S].+').Value.Trim()
    $result.Programmer = [Regex]::Match($ConsoleResponse, '(?<=Programmer\s*:\s*)[\S].+').Value.Trim()
    $result.CompiledOn = [Regex]::Match($ConsoleResponse, '(?<=Compiled On\s*:\s*)[\S].+').Value.Trim()
    $result.CompilerRev = [Regex]::Match($ConsoleResponse, '(?<=Compiler Rev\s*:\s*)[\S].+').Value.Trim()
    $result.CrestronDb = [Regex]::Match($ConsoleResponse, '(?<=CrestronDB\s*:\s*)[\S].+').Value.Trim()
    $result.DeviceDb = [Regex]::Match($ConsoleResponse, '(?<=DeviceDB\s*:\s*)[\S].+').Value.Trim()
    $result.SymLibRev = [Regex]::Match($ConsoleResponse, '(?<=SYMLIB Rev\s*:\s*)[\S].+').Value.Trim()
    $result.IoLibRev = [Regex]::Match($ConsoleResponse, '(?<=IOLIB Rev\s*:\s*)[\S].+').Value.Trim()
    $result.IopCfgRev = [Regex]::Match($ConsoleResponse, '(?<=IOPCFG Rev\s*:\s*)[\S].+').Value.Trim()
    $result.SourceEnv = [Regex]::Match($ConsoleResponse, '(?<=Source Env\s*:\s*)[\S].+').Value.Trim()
    $result.TargetRack = [Regex]::Match($ConsoleResponse, '(?<=Target Rack\s*:\s*)[\S].+').Value.Trim()
    $result.ConfigRev = [Regex]::Match($ConsoleResponse, '(?<=Config Rev\s*:\s*)[\S].+').Value.Trim()
    $result.Include4DotDat = [Regex]::Match($ConsoleResponse, '(?<=Include4(?:_2Series)?\.dat\s*:\s*)[\S].+').Value.Trim()
    $result.FriendlyName = [Regex]::Match($ConsoleResponse, '(?<=Friendly Name:\s*)[\S].+').Value.Trim()

    return $result
}

function Get-ControlSystemProgramInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Device
    )

    begin {
        $programInfoList = @()
    }

    process {
        try {
            $params = @{
                Device   = $Device.IPAddress
                Secure   = $Device.Secure
                Username = $Device.Credential.Username
                Password = $Device.Credential.Password
            }

            $session = Open-CrestronSession @params

            if ($Device.Series -ge $Series.Series3) {
            (1..10) | ForEach-Object {
                    $response = Invoke-CrestronSession $session "progcomments:$_"

                    $programInfo = Convert-ProgramInfo -Device $Device -ConsoleResponse $response

                    $programInfoList += $programInfo
                }
            }
            else {
                $response = Invoke-CrestronSession $session "progcomments"

                $programInfo = Convert-ProgramInfo -Device $Device -ConsoleResponse $response

                $programInfoList += $programInfo
            }
        }
        catch {

        }
        finally {
            if ($session) {
                Close-CrestronSession $session
            }
        }
    }

    end {
        return $programInfoList
    }
}
