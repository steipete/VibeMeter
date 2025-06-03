# CI Setup Guide for VibeMeter

This guide explains how to set up continuous integration with code signing and notarization for VibeMeter.

## Prerequisites

1. Apple Developer account with Developer ID certificates
2. GitHub repository with Actions enabled
3. macOS development machine for initial setup

## Required GitHub Secrets

Configure these secrets in your GitHub repository settings:

### Code Signing Secrets

- **`MACOS_SIGNING_CERTIFICATE_P12_BASE64`**: Base64-encoded Developer ID Application certificate
- **`MACOS_SIGNING_CERTIFICATE_PASSWORD`**: Password for the P12 certificate

### Notarization Secrets

- **`APP_STORE_CONNECT_API_KEY_P8`**: The content of your App Store Connect API key (including BEGIN/END lines)
- **`APP_STORE_CONNECT_KEY_ID`**: Your API Key ID
- **`APP_STORE_CONNECT_ISSUER_ID`**: Your Issuer ID

## Setting Up Code Signing

### 1. Export Your Developer ID Certificate

1. Open Keychain Access on your Mac
2. Find your "Developer ID Application" certificate
3. Right-click and select "Export..."
4. Save as a .p12 file with a secure password
5. Convert to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```
6. Add to GitHub secrets as `MACOS_SIGNING_CERTIFICATE_P12_BASE64`

### 2. Add Certificate Password

Add the password you used when exporting the certificate as `MACOS_SIGNING_CERTIFICATE_PASSWORD`

## Setting Up Notarization

### 1. Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access → Keys
3. Click the + button to create a new key
4. Name: "VibeMeter CI"
5. Access: "Developer" role
6. Download the .p8 key file (you can only download it once!)

### 2. Add API Credentials to GitHub

1. **`APP_STORE_CONNECT_API_KEY_P8`**: Copy the entire content of the .p8 file, including:
   ```
   -----BEGIN PRIVATE KEY-----
   [key content]
   -----END PRIVATE KEY-----
   ```

2. **`APP_STORE_CONNECT_KEY_ID`**: The Key ID shown in App Store Connect (e.g., "2X3Y4Z5A6B")

3. **`APP_STORE_CONNECT_ISSUER_ID`**: Found in App Store Connect under the API Keys tab (e.g., "69a6de7e-...")

## GitHub Actions Workflow

The workflow is configured in `.github/workflows/build-mac-app.yml` and runs on:

- Push to main branch
- Pull requests to main
- Manual workflow dispatch

### Workflow Features

- **Automatic building**: Builds the app with Xcode
- **Certificate import**: Automatically imports signing certificate into a temporary keychain
- **Code signing**: Signs the app with your Developer ID certificate
- **Testing**: Runs unit tests
- **Notarization**: Submits to Apple for notarization (main branch only)
- **DMG creation**: Creates a distributable disk image
- **Artifact uploads**: Stores build artifacts for 14 days
- **PR comments**: Adds download links to pull requests
- **Release drafts**: Creates GitHub releases (manual trigger)
- **Keychain cleanup**: Removes temporary keychain after build

### How Certificate Import Works

The CI workflow automatically handles certificate management:

1. Creates a temporary keychain with a random password
2. Decodes the base64 certificate from GitHub secrets
3. Imports the certificate into the temporary keychain
4. Configures keychain access for codesign tool
5. Uses the certificate for signing
6. Cleans up the temporary keychain after the build

This ensures your certificate is never stored on disk and is properly secured during the CI process.

## Local Development

### Building Locally

```bash
# Build without signing
./scripts/build.sh

# Build with signing (uses system keychain)
./scripts/build.sh --sign

# Build with specific configuration
./scripts/build.sh --configuration Debug
```

### Testing Notarization Locally

1. Set environment variables:
   ```bash
   export APP_STORE_CONNECT_API_KEY_P8="$(cat ~/path/to/key.p8)"
   export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
   export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"
   ```

2. Build and notarize:
   ```bash
   ./scripts/build.sh --sign
   ./scripts/notarize-app.sh build/Build/Products/Release/VibeMeter.app
   ```

## Troubleshooting

### Code Signing Issues

- **"The specified item could not be found in the keychain"**: The certificate wasn't imported properly. Check:
  - Base64 encoding is correct (no line breaks)
  - Certificate password matches
  - Certificate is valid Developer ID Application type
- **"No identity found"**: Ensure your certificate is properly exported and base64-encoded
- **"User interaction is not allowed"**: The keychain needs proper permissions (handled by scripts)
- **"Resource fork, Finder information, or similar detritus"**: Clean your build directory

### Notarization Issues

- **"Invalid credentials"**: Check your API key configuration
- **"Package Invalid"**: Ensure the app is properly signed with hardened runtime
- **"Notarization failed"**: Check Apple's status page and your developer account status

### CI-Specific Issues

- **Timeout errors**: Increase the workflow timeout in the YAML file
- **Artifact too large**: Reduce the retention period or exclude unnecessary files
- **Rate limits**: Apple has rate limits on notarization submissions

## Security Best Practices

1. **Rotate API keys regularly**: Create new keys every 6-12 months
2. **Limit key permissions**: Use the minimum required access level
3. **Monitor usage**: Check App Store Connect for unusual activity
4. **Secure your certificates**: Use strong passwords and secure storage
5. **Review logs**: Ensure secrets aren't exposed in build logs

## Additional Resources

- [Apple's Notarization Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [GitHub Actions Security](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [rcodesign Documentation](https://gregoryszorc.com/docs/apple-codesign/stable/)