function Invoke-CleanUp {
    Format-SectionHeader -Title "TASK [Clean up]"

    $runspaceJobs = Get-RSJob
    $crestronSessions = Get-CrestronSession

    if ($runspaceJobs.Count -eq 0 -and $crestronSessions.Count -eq 0) {
        Write-Console -Message "Everything is shiny clean!" -ForegroundColor Green
        return
    }

    if ($runspaceJobs.Count -gt 0) {
        $runspaceJobs | ForEach-Object {
            Write-Console -Message "notice: Removing runspace job => $($_.Name)" -ForegroundColor Yellow
            $_ | Remove-RSJob -Force
        }
    }

    if ($crestronSessions.Count -gt 0) {
        $crestronSessions | ForEach-Object {
            Write-Console -Message "notice: Closing Crestron session => $($_.Handle) : $($_.Hostname)" -ForegroundColor Yellow
            $_ | Close-CrestronSession
        }
    }

    Write-Console -Message "Everything is shiny clean now!" -ForegroundColor Green
}
