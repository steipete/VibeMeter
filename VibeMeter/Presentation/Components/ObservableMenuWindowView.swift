import AppKit

/// A view that tracks Observable properties to automatically update menu window size.
///
/// This view leverages NSObservationTrackingEnabled to automatically resize
/// the CustomMenuWindow when tracked Observable properties change.
@MainActor
final class ObservableMenuWindowView: ObservableTrackingView {
    private weak var menuWindow: CustomMenuWindow?
    private weak var statusBarButton: NSStatusBarButton?
    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    
    /// The last known content size to detect changes
    private var lastContentSize: NSSize = .zero
    
    init(menuWindow: CustomMenuWindow,
         statusBarButton: NSStatusBarButton,
         userSession: MultiProviderUserSessionData,
         spendingData: MultiProviderSpendingData) {
        self.menuWindow = menuWindow
        self.statusBarButton = statusBarButton
        self.userSession = userSession
        self.spendingData = spendingData
        
        super.init(frame: .zero)
        
        // Enable layer backing
        wantsLayer = true
        
        // Hide the view - it's only used for tracking
        isHidden = true
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func trackObservableProperties() {
        // Track properties that might affect menu window content size
        _ = userSession.isLoggedInToAnyProvider
        _ = spendingData.providersWithData.count
        _ = spendingData.hasProviderIssues
        
        // Track specific provider login states
        for provider in ServiceProvider.allCases {
            _ = userSession.isLoggedIn(to: provider)
        }
    }
    
    override func viewWillDraw() {
        super.viewWillDraw()
        
        // Check if content size might have changed
        checkForContentSizeChange()
    }
    
    override func layout() {
        super.layout()
        
        // Also check on layout changes
        checkForContentSizeChange()
    }
    
    private func checkForContentSizeChange() {
        guard let window = menuWindow,
              let button = statusBarButton,
              let hostingView = window.contentViewController?.view else { return }
        
        // Force layout to get accurate size
        hostingView.layoutSubtreeIfNeeded()
        
        // Get the new fitting size
        let newSize = hostingView.fittingSize
        
        // Only animate if size actually changed
        if abs(newSize.width - lastContentSize.width) > 1 ||
           abs(newSize.height - lastContentSize.height) > 1 {
            lastContentSize = newSize
            
            // Animate to new size
            window.animateToSize(newSize, relativeTo: button)
        }
    }
}