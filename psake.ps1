Properties {
    $ProjectRoot = $ENV:BHProjectPath
    if (!$ProjectRoot) {
        $ProjectRoot = $PSScriptRoot
    }

    $ProjectRoot = Convert-Path $ProjectRoot

    try {
        $script:IsWindows = (!(Get-Variable -Name IsWindows -ErrorAction Ignore)) -or $IsWindows
        $script:IsLinux = (Get-Variable -Name IsLinux -ErrorAction Ignore) -and $IsLinux
        $script:IsMacOS = (Get-Variable -Name IsMacOS -ErrorAction Ignore) -and $IsMacOS
        $script:IsCoreCLR = $PSVersionTable.ContainsKey('PSEdition') -and $PSVersionTable.PSEdition -eq 'Core'
    }
    catch {
        Write-Error -Message "Failed to set platform variables: $_"
    }

    $Timestamp = Get-Date -UFormat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'

    $Verbose = @{}
    if ($env:BHCommitMessage -match "!verbose") {
        $Verbose = @{ Verbose = $true }
    }
}

Task Default -Depends Build

Task Init {
    $lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}

Task Test -Depends Build {
    $lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    $pesterParams = @{
        Path         = "$ProjectRoot/tests"
        PassThru     = $true
        OutputFormat = "NUnitXml"
        OutputFile   = "$ProjectRoot/$TestFile"
    }

    if (!$IsWindows) { $pesterParameters["ExcludeTag"] = "WindowsOnly" }
    $TestResults = Invoke-Pester @pesterParams

    Remove-Item "$ProjectRoot/$TestFile" -Force -ErrorAction SilentlyContinue

    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Build -Depends Init {
    $lines

    $buildParams = @{
        SourcePath                 = $env:BHPSModuleManifest
        CopyPaths                  = @("commands", "scripts", "schema")
        OutputDirectory            = $env:BHBuildOutput
        UnversionedOutputDirectory = $true
        Verbose                    = $true
        Target                     = "CleanBuild"
    }

    Build-Module @buildParams
}

Task Deploy -Depends Test {
    $lines

    if (
        $ENV:BHBuildSystem -ne 'Unknown' -and
        $ENV:BHBranchName -eq "master" -and
        $ENV:BHCommitMessage -match '!deploy'
    ) {
        $Params = @{
            Path  = $ProjectRoot
            Force = $true
        }

        Invoke-PSDeploy @Verbose @Params
    }
    else {
        "Skipping deployment: To deploy, ensure that...`n" +
        "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" +
        "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" +
        "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)"
    }
}
