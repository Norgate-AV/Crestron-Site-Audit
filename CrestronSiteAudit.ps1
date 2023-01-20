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

[CmdletBinding()]

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
    $BackupDeviceFiles = $false
)


################################################################################
# Get the current working directory
################################################################################
if ($PSScriptRoot) {
    $cwd = $PSScriptRoot
}
else {
    $cwd = $PWD
}


################################################################################
# Import the PSCrestron module
################################################################################
try {
    $module = Join-Path -Path $cwd -ChildPath PSCrestron
    if (Test-Path -Path $module) {
        Import-Module $module
    }
    else {
        Import-Module PSCrestron
    }
}
catch {
    Write-Console -Message "error: Failed to import PSCrestron => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Source utilities
################################################################################
try {
    $utilsDirectory = Join-Path -Path $cwd -ChildPath "lib"

    Get-ChildItem -Path $utilsDirectory -Filter "*.ps1" -Recurse | ForEach-Object {
        Write-Verbose "notice: Sourcing => $($_.FullName)"
        . $_.FullName
    }
}
catch {
    Write-Console -Message "error: Failed to source utils => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Search for the environment file
################################################################################
$envFile = Find-Up -FileName ".env"

if ($envFile) {
    Write-Verbose -Message "notice: Found environment file => $envFile"
}
else {
    Write-Console -Message "error: Failed to find environment file" -ForegroundColor Red
    exit 1
}


################################################################################
# Get/Set environment variables
################################################################################
try {
    $envVariables = Get-EnvironmentFileVariableList -File $envFile

    if ($envVariables) {
        $envVariables | Foreach-Object {
            [Environment]::SetEnvironmentVariable($_.Variable, $_.Value)
        }
    }
}
catch {
    Write-Console -Message "error: Failed to set environment variables => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Check the manifest file exists
################################################################################
$ManifestFile = Resolve-Path -Path $ManifestFile

if (!(Test-Path -Path $ManifestFile -PathType "Leaf")) {
    Write-Console -Message "error: The manifest file '$ManifestFile' does not exist" -ForegroundColor Red
    exit 1
}


################################################################################
# Check the output directory exists
################################################################################
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

if (!$OutputDirectory) {
    $OutputDirectory = Join-Path -Path $cwd -ChildPath $timestamp

    Write-Verbose -Message "No output directory specified, using '$OutputDirectory'"
    Write-Verbose -Message "Use the -OutputDirectory parameter to specify an output directory"
}
else {
    if (!(Test-Path -Path $OutputDirectory -PathType "Container")) {
        Write-Console -Message "error: The output directory '$OutputDirectory' does not exist" -ForegroundColor Red
        exit 1
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
    exit 1
}

$devices = $manifest.devices
$credentials = $manifest.credentials


################################################################################
# Check there are devices to process
################################################################################
if (!$devices) {
    Write-Console -Message "error: No devices found in the manifest file '$ManifestFile'" -ForegroundColor Red
    exit 1
}


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
Write-Console -ForegroundColor Green -Message "Device File Backup => $($BackupDeviceFiles)"
Write-Console
Write-Console -ForegroundColor Green -Message "Output Directory => $OutputDirectory"
Write-Console -ForegroundColor Green -Message "Audit File => $outputFile"


################################################################################
# Gather initial device information
################################################################################
Format-SectionHeader -Title "TASK [Getting Device Information]"
$deviceInfo = @()

try {
    $runspaceJobParams = @{
        Name            = { "DeviceInfo-[$($_.address)]" }
        ScriptBlock     = $deviceInfoScriptBlock
        Throttle        = 50
        ModulesToImport = @("PSCrestron")
    }

    $devices | Start-RSJob @runspaceJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
        $errorMessage = $_.ErrorMessage

        if ($errorMessage) {
            Write-Console -Message "error: [$($_.Device)] => $errorMessage" -ForegroundColor Red
            return
        }

        $deviceInfo += $_

        Write-Console -Message "ok: [$($_.Device)]" -ForegroundColor Green
    }
}
catch {
    Write-Console -Message "error: Failed to get device information => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
}
finally {
    Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -Append
    Get-RSJob | Remove-RSJob -Force
}

if ($deviceInfo.Count -eq 0) {
    Write-Console -Message "error: Failed to get device information" -ForegroundColor Red
    Invoke-CleanUp
    exit 1
}

if ($deviceInfo.Count -ne $devices.Count) {
    Write-Console -Message "warning: Failed to get device information for all devices" -ForegroundColor Yellow
}


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
$controlSystems = @()
$controlSystems += $deviceInfo | Select-ControlSystem
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
# Filter Touch Panels
################################################################################
$touchPanels = @()
$touchPanels += $deviceInfo | Select-TouchPanel
if ($touchPanels) {
    Format-SectionHeader -Title "TOUCH PANELS"
    Set-HostForeGroundColour -Colour Green
    $touchPanels | Format-Table -Property IPAddress, Category, Hostname, Prompt, MACAddress, VersionOS, Series
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
    $runspaceJobParams = @{
        Name            = { "RuntimeInfo-[$($_.Device)]" }
        ScriptBlock     = $runtimeInfoScriptBlock
        Throttle        = 50
        ModulesToImport = @("PSCrestron")
    }

    $deviceInfo | Start-RSJob @runspaceJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
        $errorMessage = $_.RuntimeInfo.ErrorMessage

        if ($errorMessage) {
            Write-Console -Message "error: [$($_.Device)] => $errorMessage" -ForegroundColor Red
            return
        }

        $_ | Export-DeviceRuntimeInfo

        Write-Console -Message "ok: [$($_.Device)]" -ForegroundColor Green
    }
}
catch {
    Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
}
finally {
    Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -Append
    Get-RSJob | Remove-RSJob -Force
}


################################################################################
# Run device file backup
################################################################################
if ($BackupDeviceFiles) {
    Format-SectionHeader -Title "TASK [Backing up Device Files]"

    try {
        $runspaceJobParams = @{
            Name            = { "DeviceFiles-[$($_.Device)]" }
            ScriptBlock     = $deviceFilesScriptBlock
            Throttle        = 50
            ModulesToImport = @("PSCrestron")
        }

        $deviceInfo | Start-RSJob @runspaceJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
            $errorMessage = $_.ErrorMessage

            if ($errorMessage) {
                Write-Console -Message "error: [$($_.Device)] => $errorMessage" -ForegroundColor Red
                return
            }

            Write-Console -Message "ok: [$($_.Device)]" -ForegroundColor Green
        }
    }
    catch {
        Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    }
    finally {
        Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -Append
        Get-RSJob | Remove-RSJob
    }
}


################################################################################
# Run auto discovery on each device to report on any new devices
################################################################################
Format-SectionHeader -Title "TASK [Searching for Devices not in Manifest]"
$newDevices = @()

try {
    $runspaceJobParams = @{
        Name            = { "DeviceSearch-[$($_.Device)]" }
        ScriptBlock     = $deviceSearchScriptBlock
        Throttle        = 50
        ModulesToImport = @("PSCrestron")
    }

    $controlSystems | Where-Object { $_.Series -ge 3 } | Start-RSJob @runspaceJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
        if (!$_.DiscoveredDevices) {
            Write-Console -Message "error: [$($_.Device)] => Failed to read autodiscovery" -ForegroundColor Red
            return
        }

        Write-Console -Message "ok: [$($_.Device)]" -ForegroundColor Green

        if ($_.DiscoveredDevices.Count -eq 0) {
            return
        }

        $discoveredDevicesFile = Join-Path -Path $_.DeviceDirectory -ChildPath "DiscoveredDevices.xlsx"
        $_.DiscoveredDevices | Export-Excel -Path $discoveredDevicesFile -Append

        $newDevices += $_.DiscoveredDevices | Where-Object { $_.Hostname -notin $deviceInfo.Hostname }
    }
}
catch {
    Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
}
finally {
    Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -Append
    Get-RSJob | Remove-RSJob
}


################################################################################
# Report on new devices
################################################################################
Write-Console
Format-SectionHeader -Title "DISCOVERED DEVICES"
if ($newDevices) {
    Set-HostForeGroundColour -Colour Green
    $newDevices | Format-Table
    Set-HostForeGroundColour

    Write-Console -Message "New Devices Found: $($newDevices.Count)" -ForegroundColor Green
    $newDevicesFile = Join-Path -Path $OutputDirectory -ChildPath "NewDevices.xlsx"
    $newDevices | Export-Excel -Path $newDevicesFile -Append
}
else {
    Write-Console -Message "No new devices discovered" -ForegroundColor Green
}


################################################################################
# Show Summary
################################################################################
$stopwatch.Stop()
$seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 0)

Format-SectionHeader -Title "SUMMARY IN $($seconds)s"
Set-HostForeGroundColour -Colour Green
$deviceInfo | Format-Table -Property IPAddress, Category, Hostname, Prompt, MACAddress, VersionOS, ProgramFile, SourceFile, Programmer, CompiledOn

Write-Output "Total Control Systems: $(@($controlSystems).Count)"
Write-Output "Total 2-Series Control Systems: $(@($controlSystems | Where-Object { $_.Series -eq 2 }).Count)"
Write-Output "Total 3-Series Control Systems: $(@($controlSystems | Where-Object { $_.Series -eq 3 }).Count)"
Write-Output "Total 4-Series Control Systems: $(@($controlSystems | Where-Object { $_.Series -eq 4 }).Count)"
Write-Output "Total Touch Panels: $(@($touchPanels).Count)"

Set-HostForeGroundColour


################################################################################
# Export final audit report
################################################################################
$deviceInfo | Select-Object -Property * -ExcludeProperty Credential, ProgramInfo, RuntimeInfo, IPTableInfo, DiscoveredDevices | `
    Export-Excel -Path $outputFile -Append

$deviceInfo | `
    Select-Object -Property * `
    -ExcludeProperty Credential, RuntimeInfo, ProgramBootDirectory, SourceFile, ProgramFile, SystemName, Programmer, CompiledOn, `
    CompilerRev, CrestronDb, DeviceDb, SymLibRev, IoLibRev, IopCfgRev, SourceEnv, TargetRack, ConfigRev, Include4DotDat, FriendlyName, `
    Panel, Rackname, Orientation, VTpro, Database | `
    ConvertTo-Json -Depth 4 | `
    Out-File -FilePath (Join-Path -Path $OutputDirectory -ChildPath "DeviceInfo.json") -Force


################################################################################
# Clean up
################################################################################
Invoke-CleanUp
