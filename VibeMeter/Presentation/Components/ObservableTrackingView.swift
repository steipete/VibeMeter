import AppKit

/// Base NSView class that leverages automatic observation tracking.
///
/// With NSObservationTrackingEnabled, any Observable properties accessed in
/// viewWillDraw(), updateConstraints(), or layout() will automatically
/// trigger view updates when those properties change.
///
/// Subclasses should override trackObservableProperties() to specify which
/// Observable properties they want to track.
@MainActor
open class ObservableTrackingView: NSView {
    
    /// Override this method to access Observable properties that should
    /// trigger automatic view updates when they change.
    ///
    /// Example:
    /// ```swift
    /// override func trackObservableProperties() {
    ///     _ = userSession.isLoggedIn
    ///     _ = spendingData.totalSpending
    /// }
    /// ```
    open func trackObservableProperties() {
        // Subclasses should override to track specific properties
    }
    
    override open func viewWillDraw() {
        super.viewWillDraw()
        
        // Track Observable properties for automatic invalidation
        trackObservableProperties()
    }
    
    override open func updateConstraints() {
        super.updateConstraints()
        
        // Track Observable properties for automatic constraint updates
        trackObservableProperties()
    }
    
    override open func layout() {
        super.layout()
        
        // Track Observable properties for automatic layout updates
        trackObservableProperties()
    }
    
    /// Convenience method to mark the view as needing display and layout
    open func setNeedsDisplayAndLayout() {
        needsDisplay = true
        needsLayout = true
    }
}