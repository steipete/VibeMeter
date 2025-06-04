import SwiftUI

/// Improved version of GeneralSettingsView following SwiftUI-first principles
extension GeneralSettingsView {
    /// View state for currency detection
    enum CurrencyDetectionState {
        case idle
        case detecting
        case detected(String)
        case failed
    }
    
    /// Simplified binding creation following the article's approach
    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.launchAtLoginEnabled },
            set: { newValue in
                settingsManager.launchAtLoginEnabled = newValue
                startupManager.setLaunchAtLogin(enabled: newValue)
            }
        )
    }
    
    var showInDockBinding: Binding<Bool> {
        Binding(
            get: { settingsManager.showInDock },
            set: { newValue in
                settingsManager.showInDock = newValue
                NSApp.setActivationPolicy(newValue ? .regular : .accessory)
            }
        )
    }
    
    var menuBarDisplayBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { settingsManager.menuBarDisplayMode },
            set: { settingsManager.menuBarDisplayMode = $0 }
        )
    }
    
    var refreshIntervalBinding: Binding<Int> {
        Binding(
            get: { settingsManager.refreshIntervalMinutes },
            set: { settingsManager.refreshIntervalMinutes = $0 }
        )
    }
    
    var currencyBinding: Binding<String> {
        Binding(
            get: { settingsManager.selectedCurrencyCode },
            set: { newValue in
                settingsManager.selectedCurrencyCode = newValue
                UserDefaults.standard.set(true, forKey: SettingsManager.Keys.hasUserCurrencyPreference)
            }
        )
    }
}