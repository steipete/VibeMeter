import SwiftUI

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventModifier(onPress: onPress, onRelease: onRelease))
    }

    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}

/// View modifier for handling press events on buttons.
struct PressEventModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() })
    }
}

/// View modifier for showing pointing hand cursor on hover.
struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                CursorTrackingView()
                    .allowsHitTesting(false))
    }
}

/// NSViewRepresentable that handles cursor changes properly
struct CursorTrackingView: NSViewRepresentable {
    func makeNSView(context _: Context) -> CursorTrackingNSView {
        CursorTrackingNSView()
    }

    func updateNSView(_: CursorTrackingNSView, context _: Context) {
        // No updates needed
    }
}

/// Custom NSView that properly handles cursor tracking
class CursorTrackingNSView: NSView {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.invalidateCursorRects(for: self)
    }
}