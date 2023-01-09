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

function Get-ControlSystemRuntimeInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        [ValidateNotNullOrEmpty()]
        $Device
    )

    begin {
        $commands = @(
            @{
                Section  = "Device Hostname"
                Commands = @("hostname")
            },
            @{
                Section  = "Device Version Info"
                Commands = @("ver -v", "ver -all", "info", "cards", "showhw", "systemkey")
            },
            @{
                Section  = "Application Status"
                Commands = @("appstat", "taskstat", "progcomments")
            },
            @{
                Section  = "Program Registration Status"
                Commands = @("progregister")
            },
            @{
                Section  = "Program Status"
                Commands = @(
                    "progcomments",
                    "proguptime",
                    "listactivemodules",
                    "progcomments:0",
                    "listactivemodules:0",
                    "proguptime:0",
                    "progcomments:1",
                    "listactivemodules:1",
                    "proguptime:1",
                    "progcomments:2",
                    "listactivemodules:2",
                    "proguptime:2",
                    "progcomments:3",
                    "listactivemodules:3",
                    "proguptime:3",
                    "progcomments:4",
                    "listactivemodules:4",
                    "proguptime:4",
                    "progcomments:5",
                    "listactivemodules:5",
                    "proguptime:5",
                    "progcomments:6",
                    "listactivemodules:6",
                    "proguptime:6",
                    "progcomments:7",
                    "listactivemodules:7",
                    "proguptime:7",
                    "progcomments:8",
                    "listactivemodules:8",
                    "proguptime:8",
                    "progcomments:9",
                    "listactivemodules:9",
                    "proguptime:9",
                    "progcomments:10",
                    "listactivemodules:10"
                    "proguptime:10"
                )
            },
            @{
                Section  = "Network Status"
                Commands = @("ipconfig /all", "who", "ipt -t", "ipt -t -p:all", "netstat", "iproute", "listdns", "showarp")
            },
            @{
                Section  = "Control Subnet Status"
                Commands = @("dhcpl", "reservedl", "showportmap -all", "routeruptime", "routeprint", "csina", "csrout")
            },
            @{
                Section  = "Cresnet Status"
                Commands = @("reportcresnet")
            },
            @{
                Section  = "Thread Pool Info"
                Commands = @("ssptask", "threadpoolinfo")
            },
            @{
                Section  = "CPU Load (3 Requests)"
                Commands = @("cpuload", "cpuload", "cpuload")
            },
            @{
                Section  = "Memory Free"
                Commands = @("ramfree")
            },
            @{
                Section  = "Time Status"
                Commands = @("timez", "time", "uptime")
            },
            @{
                Section  = "Users & Groups"
                Commands = @("listusers", "listgroups", "listdomaingroups", "listlockedusers", "listblocked")
            },
            @{
                Section  = "Error Log"
                Commands = @("err")
            },
            @{
                Section  = "Audit Log"
                Commands = @("printauditlog")
            }
        )
    }

    process {
        $runtimeInfo = [PSCustomObject] @{
            Info         = ""
            ErrorMessage = ""
        }
        
        try {
            $session = Open-CrestronSession -Device $Device.IPAddress -Secure:$Device.Secure -Username $Device.Credential.Username -Password $Device.Credential.Password

            $runtimeInfo.Info += "Crestron $($Device.Category) Connected: $($Device.IPAddress)`r`n`r`n"

            $commands | ForEach-Object {
                Write-Verbose "notice: [$($Device.Device)]: => Adding Runtime Section [$($_.Section)]"
                $runtimeInfo.Info += "$($_.Section):`r`n`r`nInvoking Command(s): [$($_.Commands -join ", ")]`r`n`r`n"

                Write-Verbose "notice: [$($Device.Device)]: => Invoking Runtime Command(s) [$($_.Commands -join ", ")]"
                $runtimeInfo.Info += "$($_.Commands | Invoke-CrestronSession -Handle $session)`r`n`r`n"
            }
        }
        catch {
            $runtimeInfo.ErrorMessage = $_.Exception.Message
        }
        finally {
            if ($session) {
                Close-CrestronSession -Handle $session
            }
        }
    }

    end {
        return $runtimeInfo
    }
}