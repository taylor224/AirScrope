import AppKit
import SwiftUI

struct OverviewOverflowKey: PreferenceKey {
    static var defaultValue: CGFloat? { nil }
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

/// Fit the overview once on launch, preserving the window's width. The measured
/// overflow can be negative, so restored windows also lose excess blank space.
struct InitialWindowHeight: NSViewRepresentable {
    let overflow: CGFloat?

    func makeNSView(context: Context) -> SizingView { SizingView() }
    func updateNSView(_ nsView: SizingView, context: Context) {
        nsView.overflow = overflow
        nsView.fitIfNeeded()
    }

    final class SizingView: NSView {
        var overflow: CGFloat?
        private weak var sizedWindow: NSWindow?
        private var pending = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            fitIfNeeded()
        }

        func fitIfNeeded() {
            guard let window, window !== sizedWindow, overflow != nil, !pending else { return }
            pending = true
            // Apply after layout and saved-frame restoration, using the latest
            // measurement. Scans, tab changes, and manual resizes cannot repeat it.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pending = false
                guard let window = self.window, window !== self.sizedWindow,
                      let overflow = self.overflow, !window.styleMask.contains(.fullScreen),
                      let screen = window.screen else { return }
                self.sizedWindow = window
                let available = screen.visibleFrame
                var frame = window.frame
                let requiredHeight = max(window.minSize.height, ceil(frame.height + overflow))
                let height = min(requiredHeight, available.height)
                frame.origin.y = max(available.minY, min(frame.maxY, available.maxY) - height)
                frame.size.height = height
                window.setFrame(frame, display: true)
            }
        }
    }
}
