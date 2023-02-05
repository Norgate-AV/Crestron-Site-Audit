[CmdletBinding()]

param (
    [parameter(Position = 0)]
    [ValidateSet('Default', 'Init', 'Test', 'Build', 'Deploy')]
    $Task = 'Default'
)

$modules = @("PSake", "PSDeploy", "BuildHelpers", "ModuleBuilder", "Pester", "PlatyPS")

foreach ($module in $modules) {
    try {
        Remove-Module $module -Force -ErrorAction SilentlyContinue
        Import-Module $module -Force -ErrorAction Stop -Verbose
    }
    catch {
        Install-Module $module -Force -AllowClobber -Scope CurrentUser -Verbose
    }
}

Set-BuildEnvironment -BuildOutput "build" -ErrorAction SilentlyContinue

Invoke-PSake -BuildFile "$env:BHProjectPath/psake.ps1" -TaskList $Task -Verbose
exit ( [int]( !$psake.build_success ) )
