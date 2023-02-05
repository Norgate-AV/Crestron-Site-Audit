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

function Get-ToolboxAddressBookDataList {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AddressBookData,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [regex]
        $Pattern
    )

    begin {
        $list = ""
    }

    process {
        $patternMatch = $Pattern.Match($AddressBookData)

        if (!$patternMatch.Success) {
            throw "Data list matching pattern not found in address book: $Pattern"
        }

        $list = $patternMatch.Groups["list"].Value.Trim()
    }

    end {
        $list
    }
}

function Convert-ToolboxAddressBookDeviceList {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DeviceList
    )

    $pattern = [regex] '(?:(?<name>[\w\d\. _-]+)=(?<connection>[\w]+) (?<address>[\w\d\. _-]+)(?:,(?<port>\d+))?(?:;\w+ (?<username>[\w\d]+))?(?:;\w+ (?<password>[\w\d!@£$%^&*#_-]+))?(?:;console (?<console>\w+))?(?:;\w+ (?<pat_connection>\w+),)?(?:(?<pat_hostname>[\w\d\. _-]+),?)?(?:(?<pat_port>\d+))?)'

    $patternMatches = $pattern.Matches($deviceList)

    if ($patternMatches.Count -eq 0) {
        throw "No devices found in address book."
    }

    $devices = [List[PSCustomObject]]::new()

    $patternMatches | ForEach-Object {
        $match = $_

        $device = [PSCustomObject] @{
            Name          = $match.Groups["name"].Value.Trim()
            Connection    = $match.Groups["connection"].Value.Trim()
            Address       = $match.Groups["address"].Value.Trim()
            Port          = $match.Groups["port"].Value.Trim()
            Username      = $match.Groups["username"].Value.Trim()
            Password      = $match.Groups["password"].Value.Trim()
            Console       = $match.Groups["console"].Value.Trim()
            PATConnection = $match.Groups["pat_connection"].Value.Trim()
            PATHostname   = $match.Groups["pat_hostname"].Value.Trim()
            PATPort       = $match.Groups["pat_port"].Value.Trim()
        }

        $devices.Add($device)
    }

    return $devices
}

function Convert-ToolboxAddressBookCommentList {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [List[PSCustomObject]]
        $Devices,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CommentList
    )

    $pattern = [regex] '(?:(?<name>[\w\d\. _-]+)=(?<comment>.+)?)'

    $patternMatches = $pattern.Matches($CommentList)

    if ($patternMatches.Count -eq 0) {
        throw "No comments found in address book."
    }

    $patternMatches | ForEach-Object {
        $match = $_

        $device = $Devices.Where({ $_.Name -eq $match.Groups["name"].Value.Trim() })

        if ($device) {
            $device | Add-Member Comment $match.Groups["comment"].Value.Trim()
        }
    }

    return $Devices
}

function Read-ToolboxAddressBook {
    [CmdletBinding()]
    [OutputType([List[PSCustomObject]])]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AddressBook
    )

    try {
        $AddressBook = Resolve-Path -Path $AddressBook

        try {
            $content = Get-Content -Path $AddressBook -Raw
        }
        catch {
            throw "Unable to read address book file: $AddressBook"
        }

        $deviceList = $content | Get-ToolboxAddressBookDataList -Pattern '\[ComSpecs\](?<list>[\s\S]+)\[Notes\]'

        $devices = Convert-ToolboxAddressBookDeviceList -DeviceList $deviceList

        $commentList = $content | Get-ToolboxAddressBookDataList -Pattern '\[Notes\](?<list>[\s\S]+)(?:\[ExtComSpecs\])?'

        $devices = Convert-ToolboxAddressBookCommentList -Devices $devices -CommentList $commentList
    }
    catch {
        Write-Error "$($_.Exception.GetBaseException().Message)"
    }
    finally {
        $devices
    }
}
