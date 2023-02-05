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

$device = $_

$cwd = $using:PSScriptRoot

$result = @{
    Device    = $device
    Exception = $null
}

try {
    Import-Module $(Resolve-Path -Path "$cwd/CrestronSiteAudit.psd1")

    if ($device.ErrorMessage) {
        return $result
    }

    $deviceParams = @{
        Device   = $device.IPAddress
        Secure   = $device.Secure
        Username = $device.Credential.Username
        Password = $device.Credential.Password
    }

    $controlSystem = $device | Select-ControlSystem
    if ($controlSystem) {
        $commands = Import-LocalizedData -FileName ControlSystemCommands -BaseDirectory "$cwd/Commands"
        $runtimeInfoResult = $device | Get-DeviceRuntimeInfo -Commands $commands

        if (!$runtimeInfoResult.Exception) {
            $device | Add-Member RuntimeInfo $runtimeInfoResult.RuntimeInfo
        }

        $cresnetInfo = Get-CresnetInfo @deviceParams
        if ($cresnetInfo) {
            $device | Add-Member CresnetInfo $cresnetInfo
        }
    }

    $touchPanel = $device | Select-TouchPanel
    if ($touchPanel) {
        $commands = Import-LocalizedData -FileName TouchPanelCommands -BaseDirectory "$cwd/Commands"
        $runtimeInfoResult = $device | Get-DeviceRuntimeInfo -Commands $commands

        if (!$runtimeInfoResult.Exception) {
            $device | Add-Member RuntimeInfo $runtimeInfoResult.RuntimeInfo
        }
    }

    $controlSubnet = $device | Select-ControlSubnet
    if ($controlSubnet) {
        $controlSubnetPortMap = Get-CrestronPersistentPort @deviceParams -All

        $controlSubnetInfo = [PSCustomObject] @{
            DhcpLeases     = ($device | Get-ControlSubnetDhcpLeaseList).Leases
            ReservedLeases = ($device | Get-ControlSubnetReservedLeaseList).Leases
            PortMap        = $controlSubnetPortMap
        }

        $device | Add-Member ControlSubnetInfo $controlSubnetInfo
    }

    $ipTableInfo = Get-IPTable @deviceParams
    if ($ipTableInfo) {
        $device | Add-Member IPTableInfo ($ipTableInfo | Sort-Object -Property CIPId)
    }

    $result.Device = $device
}
catch {
    $result.Exception = $_.Exception
}
finally {
    $result
}
