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
    $BackupDeviceFiles = $false,

    [Parameter(Mandatory = $false)]
    [switch]
    $LogsOnly = $false
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
# Source library utilities
################################################################################
try {
    $libDirectory = Join-Path -Path $cwd -ChildPath "lib"
    $utilsDirectory = Join-Path -Path $libDirectory -ChildPath "utils"

    if (!(Test-Path -Path $utilsDirectory)) {
        throw "Cannot find path '$utilsDirectory' because it does not exist."
    }

    Get-ChildItem -Path $utilsDirectory -Filter "*.ps1" -Recurse | ForEach-Object {
        Write-Verbose "notice: Sourcing => $($_.FullName)"
        . $_.FullName
    }
}
catch {
    Write-Host "error: Failed to source library utilities => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Start pre-script checks
################################################################################
Format-SectionHeader -Title "PRE-SCRIPT CHECKS"


################################################################################
# Check scriptblock files exist
################################################################################
try {
    $scriptBlockDirectory = Join-Path -Path $libDirectory -ChildPath "scriptblocks"

    if (!(Test-Path -Path $scriptBlockDirectory)) {
        throw "Cannot find path '$scriptBlockDirectory' because it does not exist."
    }

    $getDeviceInfoScriptBlock = Join-Path -Path $scriptBlockDirectory -ChildPath "GetDeviceInfo.ps1"
    $getDeviceRuntimeInfoScriptBlock = Join-Path -Path $scriptBlockDirectory -ChildPath "GetDeviceRuntimeInfo.ps1"
    $getDeviceFilesScriptBlock = Join-Path -Path $scriptBlockDirectory -ChildPath "GetDeviceFiles.ps1"
    $getDeviceAutoDiscoveryScriptBlock = Join-Path -Path $scriptBlockDirectory -ChildPath "GetDeviceAutoDiscovery.ps1"

    $files = @(
        $getDeviceInfoScriptBlock,
        $getDeviceRuntimeInfoScriptBlock,
        $getDeviceFilesScriptBlock,
        $getDeviceAutoDiscoveryScriptBlock
    )

    $files | ForEach-Object {
        if (!(Test-Path -Path $_)) {
            throw "Cannot find path '$_' because it does not exist."
        }
    }

    Write-Console -Message "ok: All required scriptblock files exist" -ForegroundColor Green
}
catch {
    Write-Host "error: Failed checking scriptblock files exist => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Check command files exist
################################################################################
try {
    $commandsDirectory = Join-Path -Path $libDirectory -ChildPath "commands"

    if (!(Test-Path -Path $commandsDirectory)) {
        throw "Cannot find path '$commandsDirectory' because it does not exist."
    }

    $files = @(
        "ControlSystemCommands.psd1",
        "TouchPanelCommands.psd1"
    )

    $files | ForEach-Object {
        $file = Join-Path -Path $commandsDirectory -ChildPath $_

        if (!(Test-Path -Path $file)) {
            throw "Cannot find path '$file' because it does not exist."
        }
    }

    Write-Console -Message "ok: All required command files exist" -ForegroundColor Green
}
catch {
    Write-Host "error: Failed checking command files exist => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Import any local modules
################################################################################
$localModules = Get-ChildItem -Path $cwd | Select-LocalModule

$localModules | ForEach-Object {
    try {
        Import-Module -Name $_.Name -Force -Verbose:$false
    }
    catch {
        Write-Console -Message "error: Failed to import local module => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
        return
    }

    Write-Verbose "notice: Imported local module => $($_.Name)"
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
        exit 1
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
            exit 1
        }

        Write-Verbose "notice: PSDepend module installed"
    }

    Write-Verbose "notice: Importing PSDepend module"
    try {
        Import-Module -Name PSDepend -Force -Verbose:$false
    }
    catch {
        Write-Console -Message "error: Failed to import PSDepend module => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Console "ok: PSDepend module is installed and imported" -ForegroundColor Green


################################################################################
# Invoke PSDepend to resolve dependencies
################################################################################
try {
    Invoke-PSDepend -Path $cwd -Force -Verbose:$false
}
catch {
    Write-Console -Message "error: PSDepend dependency resolution failed: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}

Write-Console "ok: PSDepend dependencies resolved" -ForegroundColor Green


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


################################################################################
# Check there are devices to process
################################################################################
$devices = $manifest.devices

if (!$devices) {
    Write-Console -Message "error: No devices found in the manifest file '$ManifestFile'" -ForegroundColor Red
    exit 1
}


################################################################################
# If there are credentials, check for an env file and set the variables
################################################################################
$credentials = $manifest.credentials

if ($credentials) {
    $envFile = Find-Up -FileName ".env"

    if (!$envFile) {
        Write-Console -Message "error: Failed to find environment file" -ForegroundColor Red
        exit 1
    }

    Write-Verbose -Message "notice: Found environment file => $envFile"

    try {
        $envVariables = Get-EnvironmentFileVariableList -File $envFile
        $envVariables | Foreach-Object {
            [Environment]::SetEnvironmentVariable($_.Variable, $_.Value)
        }
    }
    catch {
        Write-Console -Message "error: Failed to set environment variables => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
        exit 1
    }

    if (!$env:AES_KEY) {
        Write-Console -Message "error: The AES_KEY environment variable is not set" -ForegroundColor Red
        exit 1
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
Write-Console -ForegroundColor Green -Message "Device File Backup => $($BackupDeviceFiles)"
Write-Console
Write-Console -ForegroundColor Green -Message "Output Directory => $OutputDirectory"
Write-Console -ForegroundColor Green -Message "Audit File => $outputFile"


################################################################################
# Gather initial device information
################################################################################
Format-SectionHeader -Title "TASK [Getting Device Information]"
$deviceInfo = @()

$commonJobParams = @{
    Throttle        = 50
    ModulesToImport = @($crestronModule.Name)
}

try {
    $script = Get-Content -Path $getDeviceInfoScriptBlock -Raw -ErrorAction Stop

    $thisJobParams = @{
        Name        = { "GetDeviceInfo-[$($_.address)]" }
        ScriptBlock = [ScriptBlock]::Create($script)
    }

    $devices | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
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
    Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -FreezeTopRow -AutoSize -Append
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
    $script = Get-Content -Path $getDeviceRuntimeInfoScriptBlock -Raw -ErrorAction Stop

    $thisJobParams = @{
        Name        = { "GetDeviceRuntimeInfo-[$($_.Device)]" }
        ScriptBlock = [ScriptBlock]::Create($script)
    }

    $deviceInfo | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
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
    Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -FreezeTopRow -AutoSize -Append
    Get-RSJob | Remove-RSJob -Force
}


################################################################################
# Run device file backup
################################################################################
if ($BackupDeviceFiles) {
    Format-SectionHeader -Title "TASK [Backing up Device Files]"

    try {
        $script = Get-Content -Path $getDeviceFilesScriptBlock -Raw -ErrorAction Stop

        $thisJobParams = @{
            Name        = { "GetDeviceFiles-[$($_.Device)]" }
            ScriptBlock = [ScriptBlock]::Create($script)
        }

        $deviceInfo | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
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
        Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -FreezeTopRow -AutoSize -Append
        Get-RSJob | Remove-RSJob
    }
}


################################################################################
# Run auto discovery on each device to report on any new devices
################################################################################
Format-SectionHeader -Title "TASK [Getting Auto Discovery Information]"
$newDevices = @()

try {
    $script = Get-Content -Path $getDeviceAutoDiscoveryScriptBlock -Raw -ErrorAction Stop

    $thisJobParams = @{
        Name        = { "GetDeviceAutoDiscovery-[$($_.Device)]" }
        ScriptBlock = [ScriptBlock]::Create($script)
    }

    $controlSystems | Where-Object { $_.Series -ge 3 } | Start-RSJob @commonJobParams @thisJobParams | Wait-RSJob | Receive-RSJob | ForEach-Object {
        if (!$_.DiscoveredDevices) {
            Write-Console -Message "error: [$($_.Device)] => Failed to read autodiscovery" -ForegroundColor Red
            return
        }

        Write-Console -Message "ok: [$($_.Device)]" -ForegroundColor Green

        if ($_.DiscoveredDevices.Count -eq 0) {
            return
        }

        $discoveredDevicesFile = Join-Path -Path $_.DeviceDirectory -ChildPath "DiscoveredDevices.xlsx"
        $_.DiscoveredDevices | Export-Excel -Path $discoveredDevicesFile -FreezeTopRow -AutoSize -Append

        $newDevices += $_.DiscoveredDevices | Where-Object { $_.Hostname -notin $deviceInfo.Hostname -and $_.Hostname -notin $newDevices.Hostname }
    }
}
catch {
    Write-Console -Message "error: $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
}
finally {
    Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -FreezeTopRow -AutoSize -Append
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
    $newDevices | Export-Excel -Path $newDevicesFile -FreezeTopRow -AutoSize -Append
}
else {
    Write-Console -Message "No new devices discovered" -ForegroundColor Green
}


################################################################################
# Export final audit report
################################################################################
$deviceInfo | Select-Object -Property * -ExcludeProperty Credential, ProgramInfo, RuntimeInfo, IPTableInfo, DiscoveredDevices | `
    Export-Excel -Path $outputFile -FreezeTopRow -AutoSize -Append

$deviceInfo | `
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
$deviceInfo | Format-Table -Property IPAddress, Category, Hostname, Prompt, MACAddress, VersionOS, ProgramFile, SourceFile, Programmer, CompiledOn

Write-Output "Total Control Systems: $(@($controlSystems).Count)"
Write-Output "Total 2-Series Control Systems: $(@($controlSystems | Where-Object { $_.Series -eq 2 }).Count)"
Write-Output "Total 3-Series Control Systems: $(@($controlSystems | Where-Object { $_.Series -eq 3 }).Count)"
Write-Output "Total 4-Series Control Systems: $(@($controlSystems | Where-Object { $_.Series -eq 4 }).Count)"
Write-Output "Total Touch Panels: $(@($touchPanels).Count)"

Set-HostForeGroundColour


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
