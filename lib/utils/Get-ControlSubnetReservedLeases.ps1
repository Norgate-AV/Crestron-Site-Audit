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

function Get-ControlSubnetReservedLeases {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        [ValidateNotNullOrEmpty()]
        $Device
    )

    begin {
        $leases = @()

        $pattern = [regex] '(?i)(?<mac>(?:[a-f\d]{2}(?: |\.|:)){5}[a-f\d]{2}) *\| *(?<ip>[\x21-\x7a][\x20-\x7a]+[\x21-\x7a]) *\| *(?<description>[\w-]+)'
    }

    process {
        try {
            $params = @{
                Device   = $Device.IPAddress
                Secure   = $Device.Secure
                Username = $Device.Credential.Username
                Password = $Device.Credential.Password
            }

            $response = ("reservedl") | Invoke-CrestronCommand @params

            $patternMatches = $pattern.Matches($response)

            $patternMatches | ForEach-Object {
                $leases += [PSCustomObject] @{
                    MacAddress  = $_.Groups["mac"].Value.ToUpper()
                    IPAddress   = $_.Groups["ip"].Value
                    Description = $_.Groups["description"].Value
                }
            }
        }
        catch {
            
        }
    }
    
    end {
        return $leases | Sort-Object -Property IPAddress
    }
}