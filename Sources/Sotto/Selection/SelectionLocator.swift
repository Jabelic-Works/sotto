import AppKit
import ApplicationServices

enum SelectionLocator {
    static func requestPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func selectionAnchor() -> CGPoint? {
        guard AXIsProcessTrusted() else { return nil }

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
        return CGPoint(x: bounds.minX, y: primaryTop - bounds.maxY - 8)
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
