function Read-AddressBookDevices {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [string]
        [ValidateNotNullOrEmpty()]
        $File
    )

    $hosts = @()

    $regex = New-Object System.Text.RegularExpressions.Regex('[\s\S]+=(auto|ctp|ssh) ([\w\.]+)')
    Get-Content -Path $File | Where-Object { $_ -match $regex } | ForEach-Object {
        $match = $regex.Match($_)

        # if ($match.Length -cgt 0) {
        #     $groups = $match.Groups
        #     $hosts += [PSCustomObject] @{
        #         Host   = $groups[2].Value
        #         Secure = $false
        #     }
        # }

        if ($match.Length -cgt 0) {
            $groups = $match.Groups
            $hosts += $groups[2].Value
        }
    }

    return $hosts
}
