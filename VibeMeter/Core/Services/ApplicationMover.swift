import AppKit
import Foundation
import os.log

/// Service responsible for detecting if the app is running from a DMG and offering to move it to Applications.
///
/// This service provides functionality to:
/// - Detect if the app is running from a mounted disk image (DMG)
/// - Check if the app is already installed in the Applications folder
/// - Offer to move the app to Applications with user consent
/// - Handle the move operation safely with proper error handling
@MainActor
final class ApplicationMover {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.vibemeter", category: "ApplicationMover")
    
    // MARK: - Public Interface
    
    /// Checks if the app should be moved to Applications and offers to do so if needed.
    /// This should be called early in the app lifecycle, typically in applicationDidFinishLaunching.
    func checkAndOfferToMoveToApplications() {
        guard shouldOfferToMove() else {
            logger.info("App is already in Applications or move not needed")
            return
        }
        
        logger.info("App is running from DMG, offering to move to Applications")
        offerToMoveToApplications()
    }
    
    // MARK: - Private Implementation
    
    /// Determines if we should offer to move the app to Applications
    private func shouldOfferToMove() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        
        // Check if already in Applications
        if isInApplicationsFolder(bundlePath) {
            logger.debug("App is already in Applications folder")
            return false
        }
        
        // Check if running from DMG or other mounted volume
        if isRunningFromDMG(bundlePath) {
            logger.debug("App is running from DMG at path: \(bundlePath)")
            return true
        }
        
        // Check if running from Downloads or Desktop (common when downloaded)
        if isRunningFromTemporaryLocation(bundlePath) {
            logger.debug("App is running from temporary location: \(bundlePath)")
            return true
        }
        
        return false
    }
    
    /// Checks if the app is already in the Applications folder
    private func isInApplicationsFolder(_ path: String) -> Bool {
        let applicationsPath = "/Applications/"
        let userApplicationsPath = NSHomeDirectory() + "/Applications/"
        
        return path.hasPrefix(applicationsPath) || path.hasPrefix(userApplicationsPath)
    }
    
    /// Checks if the app is running from a DMG (mounted disk image)
    private func isRunningFromDMG(_ path: String) -> Bool {
        // Check if path contains /Volumes/ which indicates a mounted disk image
        if path.hasPrefix("/Volumes/") {
            return true
        }
        
        // Additional check: see if the parent volume is a disk image
        // This catches cases where DMG is mounted at /Volumes/SomeName/
        let url = URL(fileURLWithPath: path)
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeNameKey])
            if let volumeName = resourceValues.volumeName {
                logger.debug("Volume name: \(volumeName)")
                
                // Most DMGs will have the app path starting with /Volumes/
                // This is a reasonable heuristic for detecting disk images
                return path.hasPrefix("/Volumes/")
            }
        } catch {
            logger.warning("Failed to get volume information: \(error)")
        }
        
        return false
    }
    
    /// Checks if app is running from Downloads, Desktop, or other temporary locations
    private func isRunningFromTemporaryLocation(_ path: String) -> Bool {
        let homeDirectory = NSHomeDirectory()
        let downloadsPath = homeDirectory + "/Downloads/"
        let desktopPath = homeDirectory + "/Desktop/"
        let documentsPath = homeDirectory + "/Documents/"
        
        return path.hasPrefix(downloadsPath) || 
               path.hasPrefix(desktopPath) || 
               path.hasPrefix(documentsPath)
    }
    
    /// Presents an alert offering to move the app to Applications
    private func offerToMoveToApplications() {
        let alert = NSAlert()
        alert.messageText = "Move VibeMeter to Applications?"
        alert.informativeText = "VibeMeter is currently running from a disk image or temporary location. Would you like to move it to your Applications folder for better performance and convenience?"
        
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Don't Move")
        
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        
        // Make sure the alert appears in front
        if let window = NSApp.windows.first {
            alert.beginSheetModal(for: window) { [weak self] response in
                self?.handleMoveResponse(response)
            }
        } else {
            // No window available, show as modal dialog
            let response = alert.runModal()
            handleMoveResponse(response)
        }
    }
    
    /// Handles the user's response to the move offer
    private func handleMoveResponse(_ response: NSApplication.ModalResponse) {
        switch response {
        case .alertFirstButtonReturn:
            // User chose "Move to Applications"
            logger.info("User chose to move app to Applications")
            performMoveToApplications()
        case .alertSecondButtonReturn:
            // User chose "Don't Move"
            logger.info("User chose not to move app to Applications")
        default:
            logger.debug("Unknown alert response: \(response.rawValue)")
        }
    }
    
    /// Performs the actual move operation to Applications
    private func performMoveToApplications() {
        let currentPath = Bundle.main.bundlePath
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "VibeMeter"
        let applicationsPath = "/Applications/\(appName).app"
        
        do {
            let fileManager = FileManager.default
            
            // Check if destination already exists
            if fileManager.fileExists(atPath: applicationsPath) {
                // Ask user if they want to replace
                let replaceAlert = NSAlert()
                replaceAlert.messageText = "Replace Existing App?"
                replaceAlert.informativeText = "An app with the same name already exists in Applications. Do you want to replace it?"
                replaceAlert.addButton(withTitle: "Replace")
                replaceAlert.addButton(withTitle: "Cancel")
                replaceAlert.alertStyle = .warning
                
                let response = replaceAlert.runModal()
                if response != .alertFirstButtonReturn {
                    logger.info("User cancelled replacement of existing app")
                    return
                }
                
                // Remove existing app
                try fileManager.removeItem(atPath: applicationsPath)
                logger.info("Removed existing app at \(applicationsPath)")
            }
            
            // Copy the app to Applications
            try fileManager.copyItem(atPath: currentPath, toPath: applicationsPath)
            logger.info("Successfully copied app to \(applicationsPath)")
            
            // Show success message and offer to relaunch
            showMoveSuccessAndRelaunch(newPath: applicationsPath)
            
        } catch {
            logger.error("Failed to move app to Applications: \(error)")
            showMoveError(error)
        }
    }
    
    /// Shows success message and offers to relaunch from Applications
    private func showMoveSuccessAndRelaunch(newPath: String) {
        let alert = NSAlert()
        alert.messageText = "App Moved Successfully"
        alert.informativeText = "VibeMeter has been moved to Applications. Would you like to quit this version and launch the one in Applications?"
        
        alert.addButton(withTitle: "Relaunch from Applications")
        alert.addButton(withTitle: "Continue Running")
        
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Launch the new version and quit this one
            launchFromApplicationsAndQuit(newPath: newPath)
        }
    }
    
    /// Launches the app from Applications and quits the current instance
    private func launchFromApplicationsAndQuit(newPath: String) {
        let workspace = NSWorkspace.shared
        let appURL = URL(fileURLWithPath: newPath)
        
        workspace.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { app, error in
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    self?.logger.error("Failed to launch app from Applications: \(error)")
                    self?.showLaunchError(error)
                } else {
                    self?.logger.info("Launched app from Applications, quitting current instance")
                    
                    // Quit current instance after a short delay to ensure the new one starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }
    
    /// Shows error message for move failures
    private func showMoveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Move App"
        alert.informativeText = "Could not move VibeMeter to Applications: \(error.localizedDescription)"
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    /// Shows error message for launch failures
    private func showLaunchError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Launch from Applications"
        alert.informativeText = "Could not launch VibeMeter from Applications: \(error.localizedDescription)\n\nYou can manually launch it from Applications later."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
}