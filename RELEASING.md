# Releasing Reading List

## One-time setup

### 1. Create a Developer ID Application certificate

You need a **Developer ID Application** certificate (not a regular development cert) to sign apps for distribution outside the Mac App Store.

1. Open **Keychain Access** on your Mac.
2. Go to **Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority**.
3. Fill in your email, select "Saved to disk", and save the CSR file.
4. Go to [Apple Developer > Certificates](https://developer.apple.com/account/resources/certificates/list).
5. Click **+**, select **Developer ID Application**, upload your CSR.
6. Download and double-click the certificate to install it in your keychain.

### 2. Export the certificate as .p12

1. Open **Keychain Access**.
2. Find your **Developer ID Application** certificate (under "My Certificates").
3. Right-click > **Export** as `.p12` format. Set a strong password.
4. Base64-encode it: `base64 -i certificate.p12 | pbcopy`

### 3. Create an app-specific password

1. Go to [appleid.apple.com](https://appleid.apple.com) > Sign-In and Security > App-Specific Passwords.
2. Generate one named "Reading List Notarization".

### 4. Find your Team ID

1. Go to [Apple Developer > Membership Details](https://developer.apple.com/account#MembershipDetailsCard).
2. Copy your **Team ID** (10-character alphanumeric string).

### 5. Find your signing identity name

Run this in Terminal:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Copy the full identity string, e.g.: `Developer ID Application: Your Name (TEAMID123)`

### 6. Add GitHub repository secrets

Go to your repo's **Settings > Secrets and variables > Actions** and add:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded .p12 file contents |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password you set when exporting the .p12 |
| `DEVELOPER_ID_APPLICATION` | Full signing identity, e.g. `Developer ID Application: Your Name (TEAM123)` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | App-specific password from step 3 |
| `TEAM_ID` | Your 10-character Team ID |

## Creating a release

Tag a new version and push:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers the GitHub Actions workflow which will:

1. Build a universal binary (ARM + Intel)
2. Sign with your Developer ID certificate
3. Notarize with Apple
4. Create a DMG and ZIP
5. Publish a GitHub Release with both artifacts

## Building locally (optional)

To build a signed and notarized release on your own machine:

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAM123)"
export APPLE_ID="your@email.com"
export APPLE_ID_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export TEAM_ID="TEAM123"

./scripts/build-release.sh
```

Artifacts are written to `.build/Reading-List-<version>.dmg` and `.build/Reading-List-<version>.zip`.

## What users get

Users download the DMG, open it, and drag "Reading List" to their Applications folder. Because the app is signed and notarized, macOS Gatekeeper will allow it to run without security warnings.

On first launch, the app asks the user to select their `~/Library/Safari/Bookmarks.plist` file via a standard file picker (required for sandbox access).
