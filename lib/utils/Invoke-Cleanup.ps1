function Invoke-CleanUp {
    # Get-RSJob | Export-Excel -Path (Join-Path -Path $OutputDirectory -ChildPath "RSJobs.xlsx") -Append
    Get-RSJob | Remove-RSJob -Force

    Get-CrestronSession | ForEach-Object {
        Write-Console -Message "notice: Closing session => $_" -ForegroundColor Yellow
        $_ | Close-CrestronSession
    }
}