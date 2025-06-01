# VibeMeter

A menu bar app to track AI tool spending, specifically designed for monitoring Cursor costs in real-time.

## About

VibeMeter was created to solve a simple problem: keeping track of rapidly growing AI development tool costs. With monthly Cursor bills approaching $900, this app provides real-time monitoring and configurable spending alerts.

Read more about the project's origin and development philosophy in [The Future of Vibe Coding](https://steipete.me/posts/2025/the-future-of-vibe-coding).

## Project Structure

This repository contains two parallel implementations:

### 🍎 Native Mac App (`mac-app/`)
- **Technology**: Swift 6 + SwiftUI
- **Features**: Native macOS menu bar integration, keychain storage, system notifications
- **Status**: More complete implementation with full feature set

### ⚡ Cross-Platform App (`electron-app/`)
- **Technology**: Electron + TypeScript + React
- **Features**: Cross-platform compatibility, web-based UI
- **Status**: Basic functionality implemented, less polished than Mac version

## Features

- Real-time Cursor spending tracking
- Configurable warning thresholds ($200, $1000)
- Monthly cost monitoring
- Currency conversion support
- Launch at startup
- Secure credential storage
- User notifications

## Development Status

⚠️ **This project is unfinished** - it was developed as a prototype during a live 3-hour workshop demonstrating AI-assisted development. While functional, it requires further refinement and polish before production use.

## Development Philosophy

VibeMeter exemplifies "vibe coding" - a collaborative approach to development using AI tools like Cursor, Gemini, and Claude. The entire codebase was created through AI assistance, showcasing the potential of human-AI collaboration in software development.

## License

MIT License - see [LICENSE](LICENSE) file for details.