import SwiftUI
import AppKit

public struct TrackpadSwipeReceiver: NSViewRepresentable {
    public var onSwipeLeft: () -> Void
    public var onSwipeRight: () -> Void

    public init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
    }

    public func makeNSView(context: Context) -> TrackpadSwipeView {
        let view = TrackpadSwipeView()
        view.onSwipeLeft = onSwipeLeft
        view.onSwipeRight = onSwipeRight
        return view
    }

    public func updateNSView(_ nsView: TrackpadSwipeView, context: Context) {
        nsView.onSwipeLeft = onSwipeLeft
        nsView.onSwipeRight = onSwipeRight
    }
}

public final class TrackpadSwipeView: NSView {
    public var onSwipeLeft: (() -> Void)?
    public var onSwipeRight: (() -> Void)?

    private var lastTriggerTime: Date = .distantPast
    private var accumulatedDeltaX: CGFloat = 0

    override public func scrollWheel(with event: NSEvent) {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > 0.38 else {
            super.scrollWheel(with: event)
            return
        }

        let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : (event.deltaX * 10)

        // Only accumulate if horizontal motion is significant (ignore vertical scrolls)
        if abs(dx) > abs(event.scrollingDeltaY) {
            accumulatedDeltaX += dx

            if accumulatedDeltaX < -16 {
                lastTriggerTime = now
                accumulatedDeltaX = 0
                onSwipeLeft?()
            } else if accumulatedDeltaX > 16 {
                lastTriggerTime = now
                accumulatedDeltaX = 0
                onSwipeRight?()
            }
        } else {
            super.scrollWheel(with: event)
        }
    }
}

