# The Great Sparkle Sandbox Safari: How We Tamed Automatic Updates in a Sandboxed macOS App

*Or: How I Learned to Stop Worrying and Love the XPC Services*

If you've ever tried to implement automatic updates in a sandboxed macOS app using Sparkle, you know it can feel like trying to solve a Rubik's cube while wearing oven mitts. After creating **12 beta releases** and spending countless hours debugging "Failed to gain authorization" errors, we finally cracked the code. Here's our journey from frustration to enlightenment.

## The Setup: VibeMeter Meets Sparkle

[VibeMeter](https://github.com/steipete/VibeMeter) is a sandboxed macOS menu bar app that tracks AI service spending. When we decided to add automatic updates using Sparkle 2.x, we thought it would be straightforward. After all, Sparkle is the de facto standard for macOS app updates, right?

Oh, sweet summer child.

## Act 1: The Mysterious Authorization Failure

Our first attempts seemed promising. The app built, signed, and notarized successfully. But when users tried to update, they were greeted with:

```
Error: Failed to gain authorization required to update target
```

This error is Sparkle's polite way of saying "I can't talk to my XPC services, and I have no idea why."

## Act 2: The Entitlements Enigma

After digging through Sparkle's documentation and Console logs, we discovered our first issue: missing mach-lookup entitlements. In a sandboxed app, Sparkle uses XPC services to perform privileged operations, and these services need special permissions to communicate.

### The Missing Piece

Our entitlements file was missing a critical entry:

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.steipete.vibemeter-spks</string>
    <string>com.steipete.vibemeter-spki</string>
</array>
```

But here's the kicker - we initially only added `-spki`, thinking it stood for "Sparkle Installer." Turns out, you need BOTH:
- `-spks`: Sparkle Server (for the Installer.xpc service)
- `-spki`: Sparkle Installer (for the installation process)

Missing either one results in the dreaded authorization error.

## Act 3: The Code Signing Circus

Next came the code signing adventures. Our notarization script was doing what seemed logical:

```bash
codesign --deep --force --sign "Developer ID" VibeMeter.app
```

But Sparkle's documentation specifically warns against using `--deep`. Why? Because it can mess up the XPC services' signatures. Instead, you need to:

1. Sign the XPC services individually
2. Sign the Sparkle framework
3. Sign the app WITHOUT `--deep`

Here's the correct approach:

```bash
# Sign XPC services first
codesign -f -s "Developer ID" -o runtime "Sparkle.framework/.../Installer.xpc"
codesign -f -s "Developer ID" -o runtime --preserve-metadata=entitlements "Sparkle.framework/.../Downloader.xpc"

# Then sign the framework
codesign -f -s "Developer ID" -o runtime "Sparkle.framework"

# Finally, sign the app WITHOUT --deep
codesign --force --sign "Developer ID" --entitlements VibeMeter.entitlements --options runtime VibeMeter.app
```

## Act 4: The Bundle ID Bamboozle

At one point, we thought we were being clever by trying to change the XPC services' bundle identifiers to match our app's namespace. Big mistake. HUGE.

Sparkle's XPC services MUST keep their original bundle IDs:
- `org.sparkle-project.InstallerLauncher`
- `org.sparkle-project.DownloaderService`

Why? Because Sparkle is hardcoded to look for these specific bundle IDs. Change them, and you'll get cryptic XPC connection errors that will make you question your career choices.

## Act 5: The Build Number Blues

Even after fixing all the sandboxing issues, we hit another snag. Users were seeing "You're up to date!" when updates were clearly available. The culprit? Our appcast generation script was defaulting build numbers to "1".

Sparkle uses build numbers (CFBundleVersion), not version strings, to determine if an update is available. If your build numbers don't increment, Sparkle thinks there's nothing new.

## The Grand Finale: It Works!

After 12 beta releases (yes, twelve!), we finally had a working setup:

### The Magic Recipe

1. **Entitlements**: Include BOTH `-spks` and `-spki` mach-lookup exceptions
2. **Bundle IDs**: Never change Sparkle's XPC service bundle IDs
3. **Code Signing**: Sign XPC services individually, never use `--deep`
4. **Build Numbers**: Always increment them, and verify your appcast
5. **Info.plist**: Set `SUEnableInstallerLauncherService = true` and `SUEnableDownloaderService = false`

### The Working Configuration

```xml
<!-- VibeMeter.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.steipete.vibemeter-spks</string>
    <string>com.steipete.vibemeter-spki</string>
</array>
```

## Lessons Learned

1. **Read the documentation carefully** - But also know that it might not cover every edge case
2. **Console.app is your friend** - Filter by your process name and watch for XPC errors
3. **Don't be clever** - Follow Sparkle's conventions exactly
4. **Test updates, not just builds** - A successful build doesn't mean updates will work
5. **Version control everything** - Including your failed attempts (they're learning experiences!)

## The Tools That Saved Our Sanity

- **Console.app**: For watching XPC connection attempts in real-time
- **codesign -dvv**: For verifying signatures and entitlements
- **plutil**: For validating plist files
- **GitHub Actions**: For consistent, reproducible builds

## Final Thoughts

Implementing Sparkle in a sandboxed app is like solving a puzzle where the pieces keep changing shape. But once you understand the rules - respect the XPC services, get your entitlements right, and sign everything properly - it works beautifully.

The irony? The final solution is actually quite simple. It's getting there that's the adventure.

## Resources

- [Sparkle Sandboxing Documentation](https://sparkle-project.org/documentation/sandboxing/)
- [Apple's Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [VibeMeter Source Code](https://github.com/steipete/VibeMeter)

---

*Special thanks to the Sparkle team for creating such a robust framework, even if it did make us question our sanity for a while. Also, shoutout to Claude for being an excellent debugging companion during this journey.*

**P.S.** If you're reading this and thinking "I should add automatic updates to my sandboxed Mac app," just remember: we created 12 beta releases to figure this out. Budget your time accordingly. ☕️