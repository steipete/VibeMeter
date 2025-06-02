# Code Signing and Notarization for VibeMeter

This document explains how to set up code signing and notarization for VibeMeter to create a distributable macOS app that users can run without security warnings.

## Prerequisites

1. **Apple Developer Program membership** ($99/year)
2. **Developer ID Application certificate** in your Keychain
3. **App Store Connect API key** for notarization

## Setting Up Code Signing

### 1. Developer ID Certificate

You need a "Developer ID Application" certificate from Apple:

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
2. Create a new certificate → Developer ID → Developer ID Application
3. Download and install the certificate in your Keychain

### 2. Environment Variables for Local Development

Create a `.env` file in the project root (this file is gitignored):

```bash
# Optional: Specify signing identity (otherwise uses first Developer ID found)
SIGN_IDENTITY="Developer ID Application: Your Name (TEAM123456)"
```

## Setting Up Notarization

### 1. Create App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/access/api)
2. Click "Generate API Key"
3. Set role to "Developer" 
4. Download the `.p8` file
5. Note the Key ID and Issuer ID

### 2. Environment Variables for Notarization

Add these to your `.env` file:

```bash
# App Store Connect API Key for notarization
APP_STORE_CONNECT_API_KEY_P8="-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----"
APP_STORE_CONNECT_KEY_ID="ABC123DEF4"
APP_STORE_CONNECT_ISSUER_ID="12345678-1234-1234-1234-123456789012"
```

## Usage

### Sign Only (for development)

```bash
./scripts/sign-and-notarize.sh --sign-only
```

### Sign and Notarize (for distribution)

```bash
./scripts/sign-and-notarize.sh --sign-and-notarize
```

### Using Individual Scripts

```bash
# Just code signing
./scripts/codesign-app.sh build/Build/Products/Release/VibeMeter.app

# Just notarization (requires signed app)
./scripts/notarize-app.sh build/Build/Products/Release/VibeMeter.app
```

## CI/CD Setup (GitHub Actions)

Add these secrets to your GitHub repository:

1. `APP_STORE_CONNECT_API_KEY_P8` - The complete .p8 key content
2. `APP_STORE_CONNECT_KEY_ID` - The Key ID  
3. `APP_STORE_CONNECT_ISSUER_ID` - The Issuer ID

The CI workflow will automatically use these for notarization when building on the main branch.

## Script Options

The `sign-and-notarize.sh` script supports various options:

```bash
# Show help
./scripts/sign-and-notarize.sh --help

# Sign and notarize with custom app path
./scripts/sign-and-notarize.sh --app-path path/to/VibeMeter.app --sign-and-notarize

# Skip stapling (for CI environments where stapling may fail)
./scripts/sign-and-notarize.sh --sign-and-notarize --skip-staple

# Don't create ZIP archive
./scripts/sign-and-notarize.sh --sign-and-notarize --no-zip

# Verbose output for debugging
./scripts/sign-and-notarize.sh --sign-and-notarize --verbose
```

## Troubleshooting

### Code Signing Issues

1. **"No signing identity found"**
   - Make sure you have a Developer ID Application certificate installed
   - Check with: `security find-identity -v -p codesigning`

2. **"User interaction is not allowed"**
   - Unlock your keychain: `security unlock-keychain`
   - Or use `security unlock-keychain -p <password> login.keychain`

### Notarization Issues

1. **"Invalid API key"**
   - Verify your API key content, ID, and Issuer ID are correct
   - Make sure the .p8 key content includes the BEGIN/END lines

2. **"App bundle not eligible for notarization"**
   - Ensure the app is properly code signed with hardened runtime
   - Check entitlements are properly configured

3. **"Notarization failed"**
   - The script will show detailed error messages
   - Common issues: unsigned binaries, invalid entitlements, prohibited code

### Testing Signed/Notarized Apps

```bash
# Verify code signature
codesign --verify --verbose=2 VibeMeter.app

# Test with Gatekeeper (should pass for notarized apps)
spctl -a -t exec -vv VibeMeter.app

# Check if notarization ticket is stapled
stapler validate VibeMeter.app
```

## File Structure

After successful signing and notarization:

```
build/
├── Build/Products/Release/VibeMeter.app  # Signed and notarized app
├── VibeMeter-notarized.zip               # Distributable archive
└── VibeMeter-1.0.0.dmg                   # DMG (if created)
```

## Security Notes

- Never commit signing certificates or API keys to version control
- Use environment variables or secure CI/CD secrets
- The `.env` file is gitignored for security
- API keys should have minimal required permissions (Developer role)

## References

- [Apple Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [notarytool Documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)