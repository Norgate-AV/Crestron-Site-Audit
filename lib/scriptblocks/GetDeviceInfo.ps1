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

$credentials = $using:credentials
$cwd = $using:PSScriptRoot

$result = @{
    Device     = $device
    Exception  = $null
    DeviceInfo = $null
}

try {
    $libDirectory = Join-Path -Path $cwd -ChildPath "lib"
    $utilsDirectory = Join-Path -Path $libDirectory -ChildPath "utils"

    Get-ChildItem -Path $utilsDirectory -Filter "*.ps1" -Recurse | ForEach-Object {
        . $_.FullName
    }

    $deviceCredential = Get-DeviceCredential -Credentials $credentials -Id $device.credentialId

    $deviceParams = @{
        Device        = $device.address
        Secure        = $device.secure
        Username      = $deviceCredential.Username
        Password      = $deviceCredential.Password
    }

    $versionInfo = Get-VersionInfo @deviceParams

    $versionInfo | Add-Member CredentialId $device.credentialId
    $versionInfo | Add-Member Credential $deviceCredential
    $versionInfo | Add-Member Secure $device.secure

    if ($versionInfo.ErrorMessage) {
        $result.DeviceInfo = $versionInfo
        return $result
    }

    $controlSystem = $versionInfo | Select-ControlSystem
    if ($controlSystem) {
        $controlSystem | Add-Member Series ($controlSystem | Get-ControlSystemSeries)

        $programInfo = $controlSystem | Get-ControlSystemProgramInfo

        $versionInfo | Add-Member ProgramInfo $programInfo
        foreach ($property in $programInfo[0].PSObject.Properties | Where-Object { $_.Name -ne "Device" }) {
            $versionInfo | Add-Member $property.Name $property.Value
        }

    }

    $touchPanel = $versionInfo | Select-TouchPanel
    if ($touchPanel) {
        $programInfo = $touchPanel | Get-TouchPanelProgramInfo

        $versionInfo | Add-Member ProgramInfo $programInfo
        foreach ($property in $programInfo[0].PSObject.Properties | Where-Object { $_.Name -ne "Device" }) {
            $versionInfo | Add-Member $property.Name $property.Value
        }
    }

    $result.DeviceInfo = $versionInfo
}
catch {
    $result.Exception = $_.Exception
}
finally {
    $result
}
