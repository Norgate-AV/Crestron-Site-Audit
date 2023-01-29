# Crestron-Site-Audit

<!-- <div align="center">
    <img src="" alt="" width="150" />
</div> -->

---

[![CI](https://github.com/Norgate-AV-Solutions-Ltd/CRestron-Site-Audit/actions/workflows/main.yml/badge.svg)](https://github.com/Norgate-AV-Solutions-Ltd/Crestron-Site-Audit/actions)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![GitHub contributors](https://img.shields.io/github/contributors/Norgate-AV-Solutions-Ltd/Crestron-Site-Audit)](https://github.com/Norgate-AV-Solutions-Ltd/Crestron-Site-Audit/graphs/contributors)

---

A PowerShell script to audit a Crestron Site.

## Contents :book:

-   [Features :white_check_mark:](#features-white_check_mark)
-   [Getting Started :rocket:](#getting-started-rocket)
    -   [Prerequisites](#prerequisites)
    -   [Create Encryption Key](#create-encryption-key)
    -   [Create Manifest File](#create-manifest-file)
-   [Usage :zap:](#usage-zap)
-   [Team :soccer:](#team-soccer)
-   [Contributing :sparkles:](#contributing-sparkles)
-   [LICENSE :balance_scale:](#license-balance_scale)

## Features :white_check_mark:

-   ✅ Device Version Information
-   ✅ Device Program Information
-   ✅ Device IP Table Information
-   ✅ Device Cresnet Information
-   ✅ Device Control Subnet Information
-   ✅ Device AutoDiscovery Information
-   ✅ Device Runtime Information
-   ✅ Optional: Device File Backup

## Getting Started :rocket:

### Prerequisites

### Create Encryption Key

Credentials are encrypted using AES256. You must first create a key. This key is used to encrypt and decrypt the credentials. The key is not stored in the manifest file. The key must be stored in a `.env` file in the same directory as the script. The key must be stored in the `AES_KEY` variable. A sample file, `.env.sample` is provided in the repository.

#### 1. Copy sample file to `.env`

```bash
cp .env.sample .env
```

#### 2. Create and enter AES key

```bash
AES_KEY=cowbell
```

The longer and more complex the key, the better.

#### 3. Keep the `.env` file secret

The `.env` file should be kept secret. It should not be committed to source control. It's recommended to add the file to your `.gitignore` file.

### Create Manifest File

Create a manifest file with the following format:

```json
{
    "credentials": [
        {
            "id": "guid",
            "name": "Friendly Name",
            "credential": "Aes256 Encrypted Credential"
        },
        {
            "id": "guid",
            "name": "Friendly Name",
            "credential": "Aes256 Encrypted Credential"
        }
    ],
    "devices": [
        {
            "address": "10.0.1.10",
            "secure": true,
            "credentialId": "guid"
        },
        {
            "address": "dev-hostname-02",
            "secure": false,
            "credentialId": ""
        },
        {
            "address": "dev-hostname-03",
            "secure": true,
            "credentialId": "guid"
        }
    ]
}
```

## Usage :zap:

```powershell
.\CrestronSiteAudit.ps1
```

## Team :soccer:

This project is maintained by the following person(s) and a bunch of [awesome contributors](https://github.com/Norgate-AV-Solutions-Ltd/Crestron-Site-Audit/graphs/contributors).

<table>
  <tr>
    <td align="center"><a href="https://github.com/damienbutt"><img src="https://avatars.githubusercontent.com/damienbutt?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Damien Butt</b></sub></a><br /></td>
  </tr>
</table>

## Contributing :sparkles:

Contributions of any kind are welcome!

Check out the [contributing guide](CONTRIBUTING.md) for more information.

## LICENSE :balance_scale:

[MIT](LICENSE)
