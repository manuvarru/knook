import AppKit
import SwiftUI

/// The screen containing the mouse cursor, falling back to the main screen.
var activeScreen: NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
        ?? NSScreen.main
        ?? NSScreen.screens.first
        ?? NSScreen()
}

@MainActor
enum OverlayWindowHelper {
    private static var dismissGeneration: UInt64 = 0

    private final class OverlayWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    static func makeFullscreenWindow() -> NSWindow {
        let window = OverlayWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return window
    }

    /// Cancel any in-flight alpha animations and snap to zero immediately.
    static func cancelAnimations(on window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window.animator().alphaValue = 0
        }
        window.alphaValue = 0
    }

    static func presentOverlay<Content: View>(
        in window: NSWindow,
        rootView: Content,
        fadeDuration: TimeInterval = 0.5,
        timingFunction: CAMediaTimingFunctionName = .easeOut
    ) {
        dismissGeneration &+= 1
        cancelAnimations(on: window)

        let screenFrame = activeScreen.frame
        window.setFrame(screenFrame, display: true)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = screenFrame
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: timingFunction)
            window.animator().alphaValue = 1
        }
    }

    static func dismissOverlay(_ window: NSWindow, fadeDuration: TimeInterval = 0.4, completion: (@MainActor @Sendable () -> Void)? = nil) {
        let generation = dismissGeneration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = fadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                guard generation == dismissGeneration else { return }
                window.orderOut(nil)
                completion?()
            }
        })
    }
}
