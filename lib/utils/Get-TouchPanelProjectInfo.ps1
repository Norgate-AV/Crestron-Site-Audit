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

    . (Join-Path -Path $typesDirectory -ChildPath "ProjectInfo.ps1")
}
catch {
    Write-Error -Message "Failed to load ProjectInfo.ps1" -ErrorAction Stop
}

function Get-TouchPanelProjectInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Device
    )

    $projectInfo = [ProjectInfo] @{
        Device = $Device.Hostname
    }
    
    $file = "~.LocalInfo.vtpage"
    $localTempFolder = Join-Path -Path $env:TEMP -ChildPath $Device.Hostname

    $comments = ""

    try {
        $fileExists = Test-FTPPath -Device $Device.IPAddress -Secure:$Device.Secure -Username $Device.Credential.Username -Password $Device.Credential.Password -RemotePath "/display/$file"
        if (!$fileExists) {
            throw
        }

        Get-FTPDirectory -Device $Device.IPAddress -Secure:$Device.Secure -Username $Device.Credential.Username -Password $Device.Credential.Password -RemoteDirectory 'display' -LocalDirectory $localTempFolder -CreateLocalDirectory

        $path = Join-Path -Path $localTempFolder -ChildPath $file
        $content = Get-Content -Path $path -Raw
        Remove-Item -Path $localTempFolder -Force -Recurse

        $comments = [Regex]::Match($content, '\[BEGIN_INFO\][\x0A-\x7E]+').Value

        $regex = [Regex]::new('[\s\S]+VTZ=([\s\S]+)[\s\S]+Date=([\w \d,:]+)[\s\S]+', [System.Text.RegularExpressions.RegexOptions]::Multiline)
        $match = $regex.Match($comments)

        if (!$match.Success) {
            throw
        }

        $groups = $match.Groups

        $projectInfo.ProgramFile = $groups[1].Value
        $projectInfo.CompiledOn = $groups[2].Value
        $projectInfo.SourceFile = ""
        $projectInfo.Programmer = ""
    }
    catch {

    }

    return $projectInfo
}