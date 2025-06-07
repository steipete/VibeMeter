import Foundation

/// Defines how the menu bar status item should display information.
///
/// This enum controls the appearance of the VibeMeter status item in the macOS menu bar,
/// allowing users to customize whether they see just the gauge icon, just the cost amount,
/// or both together. The cycling order is: icon → money → both → icon...
public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case iconOnly = "icon"
    case moneyOnly = "money"
    case both

    public var id: String { rawValue }

    /// User-friendly display name for the mode
    public var displayName: String {
        switch self {
        case .iconOnly:
            "Icon Only"
        case .moneyOnly:
            "Money Only"
        case .both:
            "Icon + Money"
        }
    }

    /// Brief description of what this mode shows
    public var description: String {
        switch self {
        case .iconOnly:
            "Shows only the gauge icon in the menu bar"
        case .moneyOnly:
            "Shows only the current spending amount"
        case .both:
            "Shows both the gauge icon and spending amount"
        }
    }

    /// Whether this mode shows the gauge icon
    public var showsIcon: Bool {
        switch self {
        case .iconOnly, .both:
            true
        case .moneyOnly:
            false
        }
    }

    /// Whether this mode shows the money text
    public var showsMoney: Bool {
        switch self {
        case .moneyOnly, .both:
            true
        case .iconOnly:
            false
        }
    }

    /// Gets the next mode in the cycling order: icon → money → both → icon...
    public var nextMode: MenuBarDisplayMode {
        switch self {
        case .iconOnly:
            .moneyOnly
        case .moneyOnly:
            .both
        case .both:
            .iconOnly
        }
    }
}
