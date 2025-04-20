
![Release Version](https://img.shields.io/github/v/release/Bioblaze/batch2steam)

# Batch2Steam GitHub Action

## Overview

The **Batch2Steam** GitHub Action is built to batch-deploy multiple depots associated with a single Steam AppID using the SteamSDK. It enables streamlined CI/CD pipelines for game developers who need to push cross-platform or modular builds in one go.

This action connects to the Steam partner network, generates individual depot VDFs for each entry, constructs a combined app VDF, and automates the upload using SteamCMD with full TOTP (Steam Guard) support.

## Inputs

### Required Inputs

- `username`: The username of your Steam builder account.
- `password`: The password for your Steam builder account.
- `shared_secret`: The shared secret for Steam's two-factor authentication. This is used to generate a time-based one-time password.
- `appId`: The unique identifier for your application within Steam's partner network.
- `rootPath`: The root path where all depot content is located.
- `entries`: A **JSON array** of entry objects containing:
  - `depotID`: The ID of the Steam depot.
  - `buildDescription`: A short description of the specific depot build.
  - `depotPath`: The subdirectory within `rootPath` where the depot's files are stored.

### Example entries input:

```json
[
  { "depotID": "123457", "buildDescription": "Windows 64-bit build", "depotPath": "windows" },
  { "depotID": "123458", "buildDescription": "Linux 32-bit build", "depotPath": "linux32" },
  { "depotID": "123459", "buildDescription": "macOS build", "depotPath": "macos" }
]
```

## Outputs

- `manifest`: The path to the generated `app_build.vdf` manifest file used in the Steam upload process.

## Environment Variables

These are internally used and set from your inputs:

- `steam_username`
- `steam_password`
- `steam_shared_secret`
- `appId`
- `rootPath`
- `entries`

## Usage

Here’s an example GitHub Actions workflow that uses **Batch2Steam** to upload multiple builds:

```yaml
name: Batch Deploy to Steam

on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Batch Deploy to Steam
      uses: bioblaze/batch2steam@v1  # Path to your action or remote repo
      with:
        username: ${{ secrets.STEAM_USERNAME }}
        password: ${{ secrets.STEAM_PASSWORD }}
        shared_secret: ${{ secrets.STEAM_SHARED_SECRET }}
        appId: '123456'
        rootPath: './build'
        entries: >
          [
            { "depotID": "123457", "buildDescription": "Windows 64-bit build", "depotPath": "windows" },
            { "depotID": "123458", "buildDescription": "Linux 32-bit build", "depotPath": "linux32" },
            { "depotID": "123459", "buildDescription": "macOS build", "depotPath": "macos" }
          ]
```

In this workflow:
- All depot folders are expected to exist under `./build/`.
- VDF files for each depot and the app are generated automatically inside the action.
- The manifest is executed via SteamCMD in a single batch operation.

## Notes

- Set up GitHub Secrets for `STEAM_USERNAME`, `STEAM_PASSWORD`, and `STEAM_SHARED_SECRET` to protect your credentials.
- Each `depotPath` must be relative to the `rootPath` and must contain the full content for that depot.
- Make sure your depots are properly configured on the Steam partner site with matching Depot IDs.

## Node.js File: `get_totp.js`

This action includes a Node.js utility (`get_totp.js`) to securely generate TOTP codes for use with Steam Guard. It reads your `shared_secret` and calculates the correct authentication code for logging in.

## How to Get the Shared Token for Steam

To obtain your Steam shared secret for use with this action, follow the guide provided:

📄 [How to Get the Shared Token for Steam (STEAM_TUTORIAL.md)](./STEAM_TUTORIAL.md)

The tutorial includes:
- Installing `steamguard-cli`
- Exporting the shared token
- Securing your revocation code for future recovery

If you need help, feel free to open an issue or contact the maintainer directly.

## License

This GitHub Action is distributed under the MIT license. See the `LICENSE` file for more details.

---

Maintained by **Randolph William Aarseth II** <<randolph@divine.games>>. Pull requests and issues welcome.