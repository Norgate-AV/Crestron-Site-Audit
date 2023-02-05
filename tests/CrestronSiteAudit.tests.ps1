if (!$env:BHProjectPath) {
    Set-BuildEnvironment -Path $PSScriptRoot/..
}

Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
Import-Module "$env:BHBuildOutput/$env:BHProjectName/$env:BHProjectName.psd1" -Force

$PSVersion = $PSVersionTable.PSVersion.Major

$Verbose = @{}
if ($env:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
    $Verbose.add("Verbose", $true)
}

Describe "$env:BHProjectName PS$PSVersion" {
    Context "Strict mode" {

        Set-StrictMode -Version Latest

        # BeforeAll {
        #     It "Should import without exception" {
        #         { Import-Module "$env:BHBuildOutput/$env:BHProjectName/$env:BHProjectName.psd1" -Force -ErrorAction Stop } | Should -Not -Throw
        #     }
        # }

        It "Should be loaded" {
            $exportedFunctions = @(
                "Invoke-CrestronSiteAudit"
            )

            $Module = Get-Module $env:BHProjectName

            $Module.Name | Should -Be $env:BHProjectName
            $exportedFunctions | ForEach-Object {
                $Module.ExportedFunctions.Keys -contains $_ | Should -Be $true
            }
        }

        It "Should always pass" {
            $true | Should -Be $true
        }
    }
}
