# Vibe Meter

A native macOS menu bar application for monitoring your monthly spending on Cursor AI.

## Features

- 📊 Real-time spending tracking in your menu bar
- 💰 Multi-currency support (USD, EUR, GBP, JPY, and more)
- 🔔 Customizable spending limit notifications
- 🔐 Secure authentication via Cursor's web login
- ⚡ Lightweight native Swift app with minimal resource usage

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for building)
- [Tuist](https://tuist.io) (for project generation)

## Building the Project

1. **Clone the repository:**
   ```bash
   git clone https://github.com/steipete/VibeMeter.git
   cd VibeMeter
   ```

2. **Generate the Xcode project:**
   ```bash
   ./scripts/generate-xcproj.sh
   ```

3. **Build and run:**
   - Open `VibeMeter.xcworkspace` in Xcode
   - Select the VibeMeter scheme
   - Press ⌘R to build and run

## Development

### Project Structure

- `VibeMeter/` - Main application code
- `VibeMeterTests/` - Unit tests
- `scripts/` - Build and distribution scripts
- `docs/` - Additional documentation

### Key Commands

```bash
# Generate Xcode project
./scripts/generate-xcproj.sh

# Format code
./scripts/format.sh

# Run linter
./scripts/lint.sh

# Run tests
xcodebuild -workspace VibeMeter.xcworkspace -scheme VibeMeter test
```

### Architecture

VibeMeter follows a clean architecture pattern with:
- **DataCoordinator** - Central state management
- **Service Layer** - API client, settings, notifications
- **UI Layer** - Menu bar controller and SwiftUI settings

## Distribution

For signed and notarized builds:

```bash
./scripts/build.sh
./scripts/codesign-app.sh
./scripts/create-dmg.sh
./scripts/notarize-app.sh
```

## Blog Post

Read about the development process: [Building a native macOS app with AI](https://steipete.com/posts/vibemeter/)

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

Peter Steinberger ([@steipete](https://twitter.com/steipete)) 