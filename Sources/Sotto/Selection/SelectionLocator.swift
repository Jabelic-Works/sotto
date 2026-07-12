import AppKit
import ApplicationServices

struct SelectionAnchor {
    enum Source {
        case selection
        case mouseFallback(reason: String)
    }

    let point: CGPoint
    let source: Source
}

enum SelectionLocator {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = [
            "AXTrustedCheckOptionPrompt": true,
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    static func selectionAnchor() -> CGPoint? {
        resolvedAnchor().point
    }

    static func resolvedAnchor() -> SelectionAnchor {
        let fallback = NSEvent.mouseLocation

        guard isTrusted else {
            return SelectionAnchor(
                point: fallback,
                source: .mouseFallback(reason: "Accessibility permission is missing")
            )
        }

        guard let selectionAnchor = selectedTextAnchor() else {
            return SelectionAnchor(
                point: fallback,
                source: .mouseFallback(reason: "Selection bounds were unavailable")
            )
        }

        return SelectionAnchor(point: selectionAnchor, source: .selection)
    }

    private static func selectedTextAnchor() -> CGPoint? {
        guard isTrusted else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                systemWide,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            ) == .success,
            let focusedValue
        else {
            return nil
        }

        let focused = focusedValue as! AXUIElement
        var rangeValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                focused,
                kAXSelectedTextRangeAttribute as CFString,
                &rangeValue
            ) == .success,
            let rangeValue
        else {
            return nil
        }

        var boundsValue: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                focused,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeValue,
                &boundsValue
            ) == .success,
            let boundsValue,
            CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var accessibilityBounds = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &accessibilityBounds) else {
            return nil
        }

        return cocoaAnchor(for: accessibilityBounds)
    }

    private static func cocoaAnchor(for bounds: CGRect) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { screen in
            let accessibilityFrame = CGRect(
                x: screen.frame.minX,
                y: NSScreen.screens[0].frame.maxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return accessibilityFrame.intersects(bounds)
        }) ?? NSScreen.main else {
            return NSEvent.mouseLocation
        }

        let primaryTop = NSScreen.screens[0].frame.maxY
        return CGPoint(x: bounds.midX, y: primaryTop - bounds.maxY)
            .clamped(to: screen.visibleFrame)
    }
}

private extension CGPoint {
    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(x, rect.minX), rect.maxX),
            y: min(max(y, rect.minY), rect.maxY)
        )
    }
}
