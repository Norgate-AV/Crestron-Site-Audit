################################################################################
# Check script files exist
################################################################################
try {
    $files = @(
        "$PSScriptRoot/GetDeviceInfo.ps1",
        "$PSScriptRoot/GetDeviceRuntimeInfo.ps1",
        "$PSScriptRoot/GetDeviceBackup.ps1",
        "$PSScriptRoot/GetDeviceAutoDiscovery.ps1"
    )

    $files | ForEach-Object {
        if (!(Test-Path -Path $_)) {
            throw "Cannot find path '$_' because it does not exist."
        }
    }
}
catch {
    Write-Host "error: Failed checking script files exist => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}


################################################################################
# Check data files exist
################################################################################
try {
    $dataDirectory = Resolve-Path -Path "$PSScriptRoot/../data"

    if (!(Test-Path -Path $dataDirectory)) {
        throw "Cannot find path '$dataDirectory' because it does not exist."
    }

    $files = @(
        "ControlSystemCommands.psd1",
        "TouchPanelCommands.psd1"
    )

    $files | ForEach-Object {
        $file = Join-Path -Path $dataDirectory -ChildPath $_

        if (!(Test-Path -Path $file)) {
            throw "Cannot find path '$file' because it does not exist."
        }
    }
}
catch {
    Write-Host "error: Failed checking data files exist => $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 1
}
