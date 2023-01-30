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

function Get-DeviceRuntimeInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        [ValidateNotNullOrEmpty()]
        $Device,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        [ValidateNotNullOrEmpty()]
        $Commands
    )

    begin {}

    process {
        $result = [PSCustomObject] @{
            Device      = $Device
            Exception   = ""
            RuntimeInfo = ""
        }

        $params = @{
            Device   = $Device.IPAddress
            Secure   = $Device.Secure
            Username = $Device.Credential.Username
            Password = $Device.Credential.Password
        }

        try {
            $session = Open-CrestronSession @params

            $result.RuntimeInfo += "Crestron $($Device.Category) Connected: $($Device.IPAddress)`r`n`r`n"

            $commands | ForEach-Object {
                Write-Verbose "notice: [$($Device.Device)]: => Adding Runtime Section [$($_.Section)]"
                $result.RuntimeInfo += "$($_.Section):`r`n`r`nInvoking Command(s): [$($_.Commands -join ", ")]`r`n`r`n"

                Write-Verbose "notice: [$($Device.Device)]: => Invoking Runtime Command(s) [$($_.Commands -join ", ")]"
                $result.RuntimeInfo += "$($_.Commands | Invoke-CrestronSession -Handle $session)`r`n`r`n"
            }
        }
        catch {
            $result.Exception = $_.Exception
        }
        finally {
            if ($session) {
                Close-CrestronSession -Handle $session
            }
        }
    }

    end {
        return $result
    }
}
