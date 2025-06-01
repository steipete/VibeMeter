# Vibe Meter

**Version:** 1.2 (as per last spec)

## Overview

Vibe Meter is a macOS menu bar application designed to help users monitor their monthly spending on the Cursor AI service. It provides at-a-glance cost information, configurable warning and upper spending limits with notifications, and multi-currency display options. The application requires users to log into their Cursor account via an embedded web view to obtain session cookies for data fetching.

## Project Status

This codebase was automatically generated based on a software specification. It includes the core application logic, UI components (menu bar, settings window), and supporting services for a functional macOS application.

Auxiliary files including `.gitignore`, `VibeMeter.entitlements`, and an `Assets.xcassets` directory structure have also been prepared.

## Next Steps (for the Developer)

To build and run this application:

1.  **Create a New macOS App Project in Xcode:**
    *   Name it appropriately (e.g., "VibeMeter").

2.  **Integrate Generated Files:**
    *   Add all the Swift files from the `VibeMeter/` subdirectory (e.g., `VibeMeterApp.swift`, `DataCoordinator.swift`, etc.) to your Xcode project.
    *   Add the generated `VibeMeter.entitlements` file to your project.
    *   Integrate the `VibeMeter/Info.plist` content into your project's main `Info.plist` (ensure `LSUIElement` is true and `NSAppTransportSecurity` settings are present).
    *   The `.gitignore` file should be placed at the root of your Git repository for this project.

3.  **Add Assets:**
    *   Populate the `Assets.xcassets/AppIcon.appiconset` with the required application icon images.
    *   Add a menu bar icon image (e.g., a 16x16 point template image, with @2x, @3x versions) to `Assets.xcassets` and name the image set `menubar-icon`.

4.  **Configure Project Settings in Xcode:**
    *   Set the correct Bundle Identifier.
    *   Choose your macOS Deployment Target.
    *   Under "Signing & Capabilities", add the "App Sandbox" capability and ensure it is configured to use the `VibeMeter.entitlements` file.

5.  **Build, Test, and Iterate:**
    *   Build and run the application on your Mac.
    *   Thoroughly test all features as outlined in the original specification.
    *   Use Console.app to view logs for debugging.

---
*This README was also partially generated.* 