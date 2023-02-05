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

using namespace System.Collections.Generic

function Invoke-CrestronSiteAudit {
    [CmdletBinding()]

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LogsOnly', Justification = 'Referenced in scriptblock.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Filter', Justification = 'Referenced in scriptblock.')]

    param(
        [Parameter(Mandatory = $false)]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(".+\.(json)$")]
        $ManifestFile = "manifest.json",

        [Parameter(Mandatory = $false)]
        [string]
        $OutputDirectory,

        [Parameter(Mandatory = $false)]
        [switch]
        $BackupDevices = $false,

        [Parameter(Mandatory = $false)]
        [regex]
        $Filter = '.*',

        [Parameter(Mandatory = $false)]
        [switch]
        $LogsOnly = $false
    )


    ################################################################################
    # Start pre-script checks
    ################################################################################
    Format-SectionHeader -Title "PRE-SCRIPT CHECKS"


    ################################################################################
    # Import any local modules
    ################################################################################
    $localModules = Get-ChildItem -Path $PWD | Select-LocalModule

    if ($localModules) {
        $localModulesList = [List[PSObject]]::new()
        $localModulesList.Add($localModules)

        $localModulesList | ForEach-Object {
            try {
                Import-Module -Name $_.FullName -Force -Verbose:$false
            }
            catch {
                Write-Console -Message "error: Failed to import local module => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
                return
            }

            Write-Verbose "notice: Imported local module => $($_.Name)"
        }
    }


    ################################################################################
    # Get loaded and available modules
    ################################################################################
    $loadedModules = Get-Module
    $availableModules = Get-Module -ListAvailable -Verbose:$false


    ################################################################################
    # Check the Crestron module is imported
    ################################################################################
    $crestronModule = $loadedModules | Where-Object { $_.Name -like "*Crestron*" }

    if (!$crestronModule) {
        Write-Verbose "notice: Crestron module is not loaded"
        $crestronModule = $availableModules | Where-Object { $_.Name -like "*Crestron*" }

        try {
            Import-Module -Name $crestronModule.Name -Force -Verbose:$false
        }
        catch {
            Write-Console -Message "error: Failed to import Crestron module => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
            Write-Console -Message "error: This script requires the Crestron module to be installed and imported." -ForegroundColor Red
            Write-Console -Message "error: Please obtain and install the Crestron module and try again." -ForegroundColor Red
            return
        }
    }

    Write-Console -Message "ok: Crestron module is installed and imported" -ForegroundColor Green


    ################################################################################
    # Check the PSDepend module is imported. Install and import if not.
    ################################################################################
    $psDependModule = $loadedModules | Where-Object { $_.Name -like "*PSDepend*" }

    if (!$psDependModule) {
        Write-Verbose "notice: PSDepend module is not loaded"
        $psDependModule = $availableModules | Where-Object { $_.Name -like "*PSDepend*" }

        if (!$psDependModule) {
            Write-Verbose "notice: PSDepend is not installed."
            Write-Verbose "notice: Installing now..."

            try {
                Install-Module -Name PSDepend -Force -Verbose:$false -Scope CurrentUser
            }
            catch {
                Write-Console -Message "error: Failed to install PSDepend module => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
                return
            }

            Write-Verbose "notice: PSDepend module installed"
        }

        Write-Verbose "notice: Importing PSDepend module"
        try {
            Import-Module -Name PSDepend -Force -Verbose:$false
        }
        catch {
            Write-Console -Message "error: Failed to import PSDepend module => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
            return
        }
    }

    Write-Console "ok: PSDepend module is installed and imported" -ForegroundColor Green


    ################################################################################
    # Invoke PSDepend to resolve dependencies
    ################################################################################
    try {
        Invoke-PSDepend -Path $PSScriptRoot -Force -Verbose:$false
    }
    catch {
        Write-Console -Message "error: PSDepend dependency resolution failed: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
        return
    }

    Write-Console "ok: PSDepend dependencies resolved" -ForegroundColor Green


    ################################################################################
    # Check the manifest file exists
    ################################################################################
    try {
        $ManifestFile = Find-Up -FileName $ManifestFile
    }
    catch {
        Write-Console -Message "error: Failed to resolve the manifest file path => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
        return
    }

    if (!(Test-Path -Path $ManifestFile -PathType "Leaf")) {
        Write-Console -Message "error: The manifest file '$ManifestFile' does not exist" -ForegroundColor Red
        return
    }


    ################################################################################
    # Check the output directory exists
    ################################################################################
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    if (!$OutputDirectory) {
        $OutputDirectory = Join-Path -Path $PWD -ChildPath $timestamp

        Write-Verbose -Message "No output directory specified, using '$OutputDirectory'"
        Write-Verbose -Message "Use the -OutputDirectory parameter to specify an output directory"
    }
    else {
        if (!(Test-Path -Path $OutputDirectory -PathType "Container")) {
            Write-Console -Message "error: The output directory '$OutputDirectory' does not exist" -ForegroundColor Red
            return
        }
    }


    ################################################################################
    # Read the manifest file
    ################################################################################
    try {
        $manifest = Get-Content -Path $ManifestFile | ConvertFrom-Json
    }
    catch {
        Write-Console -Message "error: Unable to parse manifest file '$ManifestFile'" -ForegroundColor Red
        return
    }


    ################################################################################
    # Check there are devices to process
    ################################################################################
    $devices = $manifest.devices

    if (!$devices) {
        Write-Console -Message "error: No devices found in the manifest file '$ManifestFile'" -ForegroundColor Red
        return
    }


    ################################################################################
    # If there are credentials, check for an env file and set the variables
    ################################################################################
    $credentials = $manifest.credentials

    if ($credentials) {
        $envFile = Find-Up -FileName ".env"

        if (!$envFile) {
            Write-Console -Message "error: Failed to find environment file" -ForegroundColor Red
            return
        }

        Write-Console -Message "ok: Found environment file => $envFile" -ForegroundColor Green

        try {
            $envVariables = Get-EnvironmentFileVariableList -File $envFile
            $envVariables | Foreach-Object {
                [Environment]::SetEnvironmentVariable($_.Variable, $_.Value)
            }
        }
        catch {
            Write-Console -Message "error: Failed to set environment variables => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
            return
        }

        if (!$env:AES_KEY) {
            Write-Console -Message "error: The AES_KEY environment variable is not set" -ForegroundColor Red
            return
        }

        Write-Console -Message "ok: Encryption key loaded" -ForegroundColor Green
    }


    ################################################################################
    # Pre-script checks complete
    ################################################################################
    Write-Console -Message "ok: Pre-script checks complete" -ForegroundColor Green


    ################################################################################
    # Start the audit
    ################################################################################
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $outputFile = Join-Path -Path $OutputDirectory -ChildPath "CrestronAudit_$timestamp.xlsx"
    Remove-Item -Path $outputFile -ErrorAction SilentlyContinue

    Format-SectionHeader -Title "AUDIT DETAILS"
    Write-Console -ForegroundColor Green -Message "Manifest File => $ManifestFile"
    Write-Console -ForegroundColor Green -Message "Environment File => $envFile"
    Write-Console -ForegroundColor Green -Message "Device Count => $($devices.Count)"
    Write-Console -ForegroundColor Green -Message "Device Backup => $($BackupDevices)"
    Write-Console
    Write-Console -ForegroundColor Green -Message "Output Directory => $OutputDirectory"
    Write-Console -ForegroundColor Green -Message "Audit File => $outputFile"

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'moduleName', Justification = 'Referenced in scriptblock.')]
    $moduleName = $MyInvocation.MyCommand.ModuleName

    $commonExcelParams = @{
        FreezeTopRow = $true
        BoldTopRow   = $true
        AutoSize     = $true
        AutoFilter   = $true
        Append       = $true
    }

    $commonJobParams = @{
        Throttle        = 100
        ModulesToImport = @($crestronModule.Name)
    }



    ################################################################################
    # Gather initial device information
    ################################################################################
    Format-SectionHeader -Title "TASK [Getting Device Information]"
    $deviceList = [List[PSCustomObject]]::new()

    try {
        $thisJobParams = @{
            Name     = { "GetDeviceInfo-[$($_.address)]" }
            FilePath = "$PSScriptRoot/scripts/GetDeviceInfo.ps1"
        }

        $devices | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
            $device = $_.Device
            $exception = $_.Exception
            $deviceInfo = $_.DeviceInfo

            if ($exception) {
                Write-Console -Message "error: [$($device.address)] => $($exception.GetBaseException().Message)" -ForegroundColor Red
                return
            }

            if (!$deviceInfo) {
                Write-Console -Message "error: [$($device.address)] => Failed to get device information" -ForegroundColor Red
                return
            }

            $deviceList.Add($deviceInfo)

            $errorMessage = $deviceInfo.ErrorMessage
            if ($errorMessage) {
                Write-Console -Message "error: [$($device.address)] => $errorMessage" -ForegroundColor Red
                return
            }

            Write-Console -Message "ok: [$($device.address)]" -ForegroundColor Green
        }
    }
    catch {
        Write-Console -Message "error: Failed to get device information => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    }
    finally {
        Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") @commonExcelParams
        Get-RSJob | Remove-RSJob -Force
    }

    if ($deviceList.Count -eq 0) {
        Write-Console -Message "error: Failed to get device information" -ForegroundColor Red
        Invoke-CleanUp
        return
    }

    if ($deviceList.Count -ne $devices.Count) {
        Write-Console -Message "warning: Failed to get device information for all devices" -ForegroundColor Yellow
    }

    $devicesWithoutErrors = [List[PSCustomObject]]::new($deviceList.Where({ $_.ErrorMessage -eq "" }))


    ################################################################################
    # Create the output directory
    ################################################################################
    if (!(Test-Path -Path $OutputDirectory -PathType "Container")) {
        Write-Verbose -Message "notice: Creating audit output directory => '$OutputDirectory'"
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }


    ################################################################################
    # Filter Control Systems
    ################################################################################
    $controlSystems = [List[PSCustomObject]]::new($devicesWithoutErrors.Where({ Select-ControlSystem -Device $_ }))
    if ($controlSystems) {
        Format-SectionHeader -Title "CONTROL SYSTEMS"
        Set-HostForeGroundColour -Colour Green
        $controlSystems | Format-Table -Property IPAddress, Category, Hostname, Prompt, MACAddress, VersionOS, Series
        Set-HostForeGroundColour

        $controlSystems | ForEach-Object {
            $_ | Add-Member DeviceDirectory $($_ | Get-DeviceDirectory -OutputDirectory $OutputDirectory)
        }
    }


    ################################################################################
    # Filter Control Systems by Series
    ################################################################################
    $2SeriesControlSystems = [List[PSCustomObject]]::new($controlSystems.Where({ $_.Series -eq $Series.Series2 }))
    $3SeriesControlSystems = [List[PSCustomObject]]::new($controlSystems.Where({ $_.Series -eq $Series.Series3 }))
    $4SeriesControlSystems = [List[PSCustomObject]]::new($controlSystems.Where({ $_.Series -eq $Series.Series4 }))


    ################################################################################
    # Filter Touch Panels
    ################################################################################
    $touchPanels = [List[PSCustomObject]]::new($devicesWithoutErrors.Where({ Select-TouchPanel -Device $_ }))
    if ($touchPanels) {
        Format-SectionHeader -Title "TOUCH PANELS"
        Set-HostForeGroundColour -Colour Green
        $touchPanels | Format-Table -Property IPAddress, Category, Hostname, Prompt, MACAddress, VersionOS
        Set-HostForeGroundColour

        $touchPanels | ForEach-Object {
            $_ | Add-Member DeviceDirectory $($_ | Get-DeviceDirectory -OutputDirectory $OutputDirectory)
        }
    }


    ################################################################################
    # Get runtime information
    ################################################################################
    Format-SectionHeader -Title "TASK [Getting Runtime Information]"

    try {
        $thisJobParams = @{
            Name     = { "GetDeviceRuntimeInfo-[$($_.Device)]" }
            FilePath = "$PSScriptRoot/scripts/GetDeviceRuntimeInfo.ps1"
        }

        $devicesWithoutErrors | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
            $device = $_.Device
            $exception = $_.Exception

            if ($exception) {
                Write-Console -Message "error: [$($device.Device)] => $($exception.GetBaseException().Message)" -ForegroundColor Red
                return
            }

            $errorMessage = $device.RuntimeInfo.ErrorMessage
            if ($errorMessage) {
                Write-Console -Message "error: [$($device.Device)] => $errorMessage" -ForegroundColor Red
                return
            }

            $device | Export-DeviceRuntimeInfo -ExcelParams $commonExcelParams

            Write-Console -Message "ok: [$($device.Device)]" -ForegroundColor Green
        }
    }
    catch {
        Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    }
    finally {
        Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") @commonExcelParams
        Get-RSJob | Remove-RSJob -Force
    }


    ################################################################################
    # Run device backup
    ################################################################################
    if ($BackupDevices) {
        Format-SectionHeader -Title "TASK [Getting Device Backups]"

        $devicesToBackup = [List[PSCustomObject]]::new()
        $devicesToBackup.AddRange($3SeriesControlSystems.ToArray())
        $devicesToBackup.AddRange($4SeriesControlSystems.ToArray())
        $devicesToBackup.AddRange($touchPanels.ToArray())

        if ($devicesToBackup) {
            Write-Console -Message "notice: Backing up $($devicesToBackup.Count) devices" -ForegroundColor Yellow

            try {
                $thisJobParams = @{
                    Name     = { "GetDeviceBackup-[$($_.Device)]" }
                    FilePath = "$PSScriptRoot/scripts/GetDeviceBackup.ps1"
                }

                $devicesToBackup | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
                    $device = $_.Device
                    $exception = $_.Exception

                    if ($exception) {
                        Write-Console -Message "error: [$($device.Device)] => $($exception.GetBaseException().Message)" -ForegroundColor Red
                        return
                    }

                    $errorMessage = $device.ErrorMessage
                    if ($errorMessage) {
                        Write-Console -Message "error: [$($device.Device)] => $errorMessage" -ForegroundColor Red
                        return
                    }

                    Write-Console -Message "ok: [$($device.Device)]" -ForegroundColor Green
                }
            }
            catch {
                Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
            }
            finally {
                Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") @commonExcelParams
                Get-RSJob | Remove-RSJob
            }
        }
        else {
            Write-Console -Message "notice: There are no compatible devices to backup" -ForegroundColor Yellow
        }
    }


    ################################################################################
    # Run auto discovery on each device to report on any new devices
    ################################################################################
    Format-SectionHeader -Title "TASK [Getting Auto Discovery Information]"
    $newDevices = @()

    try {
        $thisJobParams = @{
            Name     = { "GetDeviceAutoDiscovery-[$($_.Device)]" }
            FilePath = "$PSScriptRoot/scripts/GetDeviceAutoDiscovery.ps1"
        }

        $controlSystems | Where-Object { $_.Series -ge $Series.Series3 } | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
            $device = $_.Device
            $exception = $_.Exception

            if ($exception) {
                Write-Console -Message "error: [$($device.Device)] => $($exception.GetBaseException().Message)" -ForegroundColor Red
                return
            }

            if (!$device.DiscoveredDevices) {
                Write-Console -Message "error: [$($device.Device)] => Failed to read autodiscovery" -ForegroundColor Red
                return
            }

            Write-Console -Message "ok: [$($device.Device)]" -ForegroundColor Green

            if ($device.DiscoveredDevices.Count -eq 0) {
                return
            }

            $discoveredDevicesFile = Join-Path -Path $device.DeviceDirectory -ChildPath "DiscoveredDevices.xlsx"
            $device.DiscoveredDevices | Export-Excel -Path $discoveredDevicesFile @commonExcelParams

            $newDevices += $device.DiscoveredDevices | Where-Object { $_.Hostname -notin $deviceList.Hostname -and $_.Hostname -notin $newDevices.Hostname }
        }
    }
    catch {
        Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    }
    finally {
        Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") @commonExcelParams
        Get-RSJob | Remove-RSJob
    }


    ################################################################################
    # Report on new devices
    ################################################################################
    Format-SectionHeader -Title "DISCOVERED DEVICES"
    if ($newDevices) {
        Set-HostForeGroundColour -Colour Yellow
        $newDevices | Format-Table
        Set-HostForeGroundColour

        Write-Console -Message "notice: Unaudited Devices Found => $($newDevices.Count)" -ForegroundColor Yellow
        Write-Console -Message "notice: These devices have not been audited because they are not included in the manifest" -ForegroundColor Yellow
        $newDevicesFile = Join-Path -Path $OutputDirectory -ChildPath "UnauditedDevices.xlsx"
        $newDevices | Export-Excel -Path $newDevicesFile @commonExcelParams
    }
    else {
        Write-Console -Message "ok: No unaudited devices discovered" -ForegroundColor Green
    }


    ################################################################################
    # Export final audit report
    ################################################################################
    $deviceList | Select-Object -Property * -ExcludeProperty Credential, ProgramInfo, RuntimeInfo, IPTableInfo, DiscoveredDevices | `
        Export-Excel -Path $outputFile @commonExcelParams

    $deviceList | `
        Select-Object -Property * `
        -ExcludeProperty Credential, RuntimeInfo, ProgramBootDirectory, SourceFile, ProgramFile, SystemName, Programmer, CompiledOn, `
        CompilerRev, CrestronDb, DeviceDb, SymLibRev, IoLibRev, IopCfgRev, SourceEnv, TargetRack, ConfigRev, Include4DotDat, FriendlyName, `
        Panel, Rackname, Orientation, VTpro, Database | `
        ConvertTo-Json -Depth 4 | `
        Out-File -FilePath (Join-Path -Path $OutputDirectory -ChildPath "DeviceInfo.json") -Force


    ################################################################################
    # Show Summary
    ################################################################################
    $stopwatch.Stop()
    $seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 0)
    $timespan = New-TimeSpan -Seconds $seconds

    Format-SectionHeader -Title "SUMMARY IN $($timespan.ToString("h'h 'm'm 's's'"))"
    Set-HostForeGroundColour -Colour Green
    $devicesWithoutErrors | Format-Table -Property IPAddress, Category, Hostname, Prompt, MACAddress, VersionOS, ProgramFile, SourceFile, Programmer, CompiledOn

    Write-Output "Total Control Systems: $($controlSystems.Count)"
    Write-Output "Total 2-Series Control Systems: $($2SeriesControlSystems.Count)"
    Write-Output "Total 3-Series Control Systems: $($3SeriesControlSystems.Count)"
    Write-Output "Total 4-Series Control Systems: $($4SeriesControlSystems.Count)"
    Write-Output "Total Touch Panels: $($touchPanels.Count)"

    Set-HostForeGroundColour

    Write-Console
    if ($newDevices.Count) {
        Write-Console -Message "Total Unaudited Devices: $($newDevices.Count)" -ForegroundColor Yellow
    }
    else {
        Write-Console -Message "Total Unaudited Devices: $($newDevices.Count)" -ForegroundColor Green
    }


    ################################################################################
    # Clean up
    ################################################################################
    Invoke-CleanUp


    ################################################################################
    # Offer advice on next steps
    ################################################################################
    Format-SectionHeader -Title "NEXT STEPS"
    Write-Console
    Write-Console -Message "1. Open the audit directory" -ForegroundColor Green
    Write-Console -Message "`t$($OutputDirectory)" -ForegroundColor Green
    Write-Console
    Write-Console -Message "2. Review the audit report" -ForegroundColor Green
    Write-Console -Message "`t$($outputFile)" -ForegroundColor Green
}
