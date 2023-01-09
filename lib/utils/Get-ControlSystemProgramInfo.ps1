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

try {
    $parentDirectory = Split-Path -Parent $PSCommandPath

    $libDirectory = Join-Path -Path $parentDirectory -ChildPath ".." -Resolve
    $typesDirectory = Join-Path -Path $libDirectory -ChildPath "types" -Resolve

    . (Join-Path -Path $typesDirectory -ChildPath "ProgramInfo.ps1")
}
catch {
    Write-Error -Message "Failed to load ProgramInfo.ps1" -ErrorAction Stop
}

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

    $result = [ProgramInfo] @{
        Device = $Device.Hostname
    }

    $pattern = '[\s\S]+Program Boot Directory[\s]*:[\s]*([\s\S]+)[\s\S]+Source File[\s]*:[\s]*([\s\S]+)[\s\S]+Program File[\s]*:[\s]*([\s\S].+)[\s\S]+System Name[\s]*:[\s]*([\s\S]+)[\s\S]+Programmer[\s]*:[\s]*([\s\S]+)[\s\S]+Compiled On[\s]*:[\s]*([\w\ \/\:]+)[\s\S]+Compiler Rev[\s]*:[\s]*([\w\.]+)[\s\S]+CrestronDB[\s]*:[\s]*([\w\.]+)[\s\S]+DeviceDB[\s]*:[\s]*([\w\.]+)[\s\S]+SYMLIB Rev[\s]*:[\s]*([\w\.]+)[\s\S]+IOLIB Rev[\s]*:[\s]*([\w\.]+)[\s\S]+IOPCFG Rev[\s]*:[\s]*([\w\.]+)[\s\S]+Source Env[\s]*:[\s]*([\s\S].+)[\s\S]+Target Rack[\s]*:[\s]*([\s\S].+)[\s\S]+Config Rev[\s]*:[\s]*([\w\.]+)[\s\S]+Include4\.dat[\s]*:[\s]*([\w\.]+)[\s\S]+Friendly Name[\s]*:[\s]*([\w\.]+)'

    $regex = [Regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

    $match = $regex.Match($ConsoleResponse)
                
    if (!$match.Success) {
        return $result
    }
    
    $groups = $match.Groups
    
    $result.ProgramBootDirectory = $groups[1].Value
    $result.SourceFile = $groups[2].Value
    $result.ProgramFile = $groups[3].Value
    $result.SystemName = $groups[4].Value
    $result.Programmer = $groups[5].Value
    $result.CompiledOn = $groups[6].Value
    $result.CompilerRev = $groups[7].Value
    $result.CrestronDb = $groups[8].Value
    $result.DeviceDb = $groups[9].Value
    $result.SymLibRev = $groups[10].Value
    $result.IoLibRev = $groups[11].Value
    $result.IopCfgRev = $groups[12].Value
    $result.SourceEnv = $groups[13].Value
    $result.TargetRack = $groups[14].Value
    $result.ConfigRev = $groups[15].Value
    $result.Include4DotDat = $groups[16].Value
    $result.FriendlyName = $groups[17].Value

    return $result
}

function Get-ControlSystemProgramInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Device
    )

    $programInfoList = @()
    
    try {
        $session = Open-CrestronSession -Device $Device.IPAddress -Secure:$Device.Secure -Username $Device.Credential.Username -Password $Device.Credential.Password

        if ($Device.Series -ge 3) {
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
    
    return $programInfoList
}