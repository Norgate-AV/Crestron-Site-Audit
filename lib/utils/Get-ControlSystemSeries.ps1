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

Set-Variable -Name Series2 -Value 2 -Option ReadOnly -Scope Global -Force
Set-Variable -Name Series3 -Value 3 -Option ReadOnly -Scope Global -Force
Set-Variable -Name Series4 -Value 4 -Option ReadOnly -Scope Global -Force
Set-Variable -Name Series -Value @{
    Series2 = $Series2
    Series3 = $Series3
    Series4 = $Series4
} -Option ReadOnly -Scope Global -Force

function Get-ControlSystemSeries {
    [CmdletBinding()]
    [OutputType([int])]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject] $Device
    )

    begin {
        $result = 0
    }

    process {
        if ($Device.Category -ne "Control System") {
            return $result
        }

        $pattern = '^[A-Z]+(?<series>\d)'
    
        $match = [regex]::Match($Device.Prompt, $pattern)

        if ($match.Success) {
            $result = [int] $match.Groups['series'].Value
        }
        else {
            $result = $Series.Series2
        }
    }

    end {
        return $result
    }
}