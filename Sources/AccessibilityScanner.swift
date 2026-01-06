import Cocoa
import ApplicationServices

/// Scans for interactive UI elements using Accessibility API
class AccessibilityScanner {

    // MARK: - Scanned Element

    struct InteractiveElement {
        let center: CGPoint
        let bounds: CGRect
        let type: ElementType
        let title: String?
    }

    enum ElementType {
        case button
        case textField
        case textArea
        case searchField
        case secureTextField
        case link
        case checkbox
        case radioButton
        case popupButton
        case slider
        case menuItem
        case tab
        case toggle
        case unknown

        /// Magnetic profile distances for this element type
        var magneticDistances: (outer: CGFloat, middle: CGFloat, inner: CGFloat) {
            switch self {
            case .textField, .textArea, .searchField, .secureTextField:
                return (100, 60, 30)  // Text fields get strongest magnetism
            case .button, .popupButton:
                return (80, 50, 25)   // Standard magnetism
            case .slider:
                return (90, 55, 30)   // Slightly stronger for sliders
            case .link, .menuItem:
                return (60, 35, 20)   // Lighter for inline elements
            default:
                return (80, 50, 25)   // Default medium
            }
        }

        /// Color for visual overlay
        var glowColor: NSColor {
            switch self {
            case .textField, .textArea, .searchField, .secureTextField:
                return .systemBlue
            case .button, .popupButton:
                return .systemGreen
            case .link, .menuItem:
                return .systemPurple
            default:
                return .systemOrange
            }
        }
    }

    // MARK: - Cache

    private struct CachedScan {
        let elements: [InteractiveElement]
        let timestamp: Date
        let centerPoint: CGPoint
    }

    private struct CachedWindowList {
        let windows: [[String: Any]]
        let timestamp: Date
    }

    private var cache: CachedScan?
    private var windowListCache: CachedWindowList?
    private let cacheValidityDuration: TimeInterval = 0.15  // 150ms cache
    private let windowListCacheDuration: TimeInterval = 0.25  // 250ms cache for window list (performance)
    private let maxScanRadius: CGFloat = 120  // Scan 120px around cursor (max magnetic range + margin)

    // MARK: - Scanning

    /// Get interactive elements near a point (with caching)
    func getElementsNear(_ point: CGPoint, radius: CGFloat) -> [InteractiveElement] {
        // Check cache validity
        if let cached = cache,
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration,
           cached.centerPoint.distance(to: point) < 100 {  // Cache valid if cursor hasn't moved far
            return cached.elements
        }

        // Perform fresh scan
        let elements = scanElementsNear(point, radius: radius)

        // Update cache
        cache = CachedScan(elements: elements, timestamp: Date(), centerPoint: point)

        return elements
    }

    /// Invalidate cache (call when window focus changes)
    func invalidateCache() {
        cache = nil
    }

    // MARK: - Private Scanning Logic

    private func scanElementsNear(_ point: CGPoint, radius: CGFloat) -> [InteractiveElement] {
        var results: [InteractiveElement] = []

        // Check accessibility permission first
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let hasPermission = AXIsProcessTrustedWithOptions(options)

        if !hasPermission {
            NSLog("🔒 No accessibility permission - cannot scan UI elements from other apps")
            return results
        }

        // Get the UI element at the cursor position
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let copyResult = ApplicationServices.AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &element
        )

        guard copyResult == .success, let foundElement = element else {
            NSLog("🔍 Failed to get element at position (%.0f, %.0f): error code %d", point.x, point.y, copyResult.rawValue)
            return results
        }

        // Check if this element belongs to our overlay window - if so, skip it
        // (Allow scanning our main app window to support sticky mouse in our own settings)
        if isOverlayWindow(foundElement) {
            NSLog("🔍 Skipping - cursor is over our overlay window")
            return results
        }

        // Get the window containing this element
        if let window = getWindowElement(from: foundElement) {
            // Log the app name for debugging
            if let appName = getAppName(foundElement) {
                NSLog("🔍 Scanning window from: %@", appName)
            }

            // Recursively search for interactive elements in this window
            searchForInteractiveElements(in: window, nearPoint: point, radius: radius, results: &results)
            NSLog("🔍 Scan complete: found %d interactive elements near (%.0f, %.0f)", results.count, point.x, point.y)
        } else {
            NSLog("🔍 Could not find window element at (%.0f, %.0f)", point.x, point.y)
        }

        return results
    }

    /// Check if an accessibility element belongs to our overlay window
    /// (We allow sticky mouse to work in our main app window, just not the overlay)
    private func isOverlayWindow(_ element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        let result = AXUIElementGetPid(element, &pid)
        guard result == .success else { return false }

        // Not our app at all? Allow it
        if pid != ProcessInfo.processInfo.processIdentifier {
            return false
        }

        // It's our app - check if it's specifically the overlay window
        // Try to get window title or role description
        if let window = getWindowElement(from: element) {
            // StatusOverlay windows have specific title pattern or could be identified by level
            // For now, we'll use a heuristic: if it's a floating window from our app, it's likely the overlay
            // A more robust solution would involve checking window title

            // Simple approach: check if window has title "Status" or "Help" (our overlays)
            if let title = getTitle(window) {
                if title.contains("Status") || title.contains("Help") || title.isEmpty {
                    return true  // This is our overlay
                }
            }
        }

        // If we can't determine, assume it's NOT the overlay (main window)
        return false
    }

    /// Get the app name for an accessibility element (for logging)
    private func getAppName(_ element: AXUIElement) -> String? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }

        let app = NSRunningApplication(processIdentifier: pid)
        return app?.localizedName
    }

    /// Get cached window list (for performance)
    private func getCachedWindowList() -> [[String: Any]]? {
        // Check if cache is still valid
        if let cached = windowListCache,
           Date().timeIntervalSince(cached.timestamp) < windowListCacheDuration {
            return cached.windows
        }

        // Refresh cache
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        // Update cache
        windowListCache = CachedWindowList(windows: windows, timestamp: Date())
        return windows
    }

    /// Check if an element is visible (not occluded by other windows)
    private func isElementVisibleAtPoint(
        bounds: CGRect,
        ownerPID: pid_t,
        nearPoint: CGPoint
    ) -> Bool {
        // Performance: Skip expensive occlusion check for distant elements
        // Elements beyond max magnetic range (100px) don't affect cursor anyway
        let elementCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let distance = elementCenter.distance(to: nearPoint)
        if distance > 100 {
            return true  // Too far to have magnetic effect, assume visible
        }

        // Get all windows in Z-order (front to back)
        guard let windows = getCachedWindowList() else {
            // Can't check - assume visible (fail open)
            return true
        }

        var foundOurWindow = false
        let ourAppPID = ProcessInfo.processInfo.processIdentifier

        for windowInfo in windows {
            guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            // Skip our own overlay windows
            if windowPID == ourAppPID {
                // Check if this is our overlay window by checking window level
                if let windowLevel = windowInfo[kCGWindowLayer as String] as? Int,
                   windowLevel > 0 {  // Overlay windows are at floating level (> 0)
                    continue  // Skip overlay, keep checking for occlusion
                }
            }

            // Found the window containing our element
            if windowPID == ownerPID {
                foundOurWindow = true
                continue  // Don't check our own window for occlusion
            }

            // If we haven't found our window yet, this window is in front of ours
            if !foundOurWindow {
                // Check if this front window overlaps our element bounds
                if let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] {
                    if let x = boundsDict["X"] as? CGFloat,
                       let y = boundsDict["Y"] as? CGFloat,
                       let w = boundsDict["Width"] as? CGFloat,
                       let h = boundsDict["Height"] as? CGFloat {
                        let windowBounds = CGRect(x: x, y: y, width: w, height: h)

                        // Check if window overlaps our element
                        if windowBounds.intersects(bounds) {
                            // This window occludes our element (removed verbose logging for performance)
                            return false
                        }
                    }
                }
            }
        }

        // Not occluded
        return true
    }

    private func getWindowElement(from element: AXUIElement) -> AXUIElement? {
        // Try to get the window directly
        if let role = getRole(element), role == "AXWindow" {
            return element
        }

        // Traverse up to find window
        var current = element
        for _ in 0..<10 {  // Limit traversal depth
            if let parent = getParent(current) {
                if let role = getRole(parent), role == "AXWindow" {
                    return parent
                }
                current = parent
            } else {
                break
            }
        }

        return nil
    }

    private func searchForInteractiveElements(
        in element: AXUIElement,
        nearPoint: CGPoint,
        radius: CGFloat,
        results: inout [InteractiveElement],
        depth: Int = 0
    ) {
        // Limit recursion depth to avoid performance issues
        guard depth < 15 else { return }

        // Check if this element is interactive
        if let interactiveElem = checkIfInteractive(element, nearPoint: nearPoint, radius: radius) {
            results.append(interactiveElem)
        }

        // Recursively check children
        if let children = getChildren(element) {
            for child in children {
                searchForInteractiveElements(
                    in: child,
                    nearPoint: nearPoint,
                    radius: radius,
                    results: &results,
                    depth: depth + 1
                )
            }
        }
    }

    private func checkIfInteractive(
        _ element: AXUIElement,
        nearPoint: CGPoint,
        radius: CGFloat
    ) -> InteractiveElement? {
        // Get element role
        guard let role = getRole(element) else { return nil }

        // Check if it's an interactive type
        let elementType = mapRoleToElementType(role)
        guard elementType != .unknown else { return nil }

        // Get element bounds
        guard let bounds = getBounds(element) else { return nil }

        // Check if element is near the point
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard center.distance(to: nearPoint) <= radius else { return nil }

        // Check if element is enabled (skip disabled elements)
        if let enabled = getEnabled(element), !enabled {
            return nil
        }

        // Get element owner PID
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }

        // Check if element is visible (not occluded by other windows)
        if !isElementVisibleAtPoint(bounds: bounds, ownerPID: pid, nearPoint: nearPoint) {
            return nil  // Occluded, filter out
        }

        // Get title/label (optional)
        let title = getTitle(element)

        return InteractiveElement(
            center: center,
            bounds: bounds,
            type: elementType,
            title: title
        )
    }

    private func mapRoleToElementType(_ role: String) -> ElementType {
        switch role {
        case "AXButton":
            return .button
        case "AXTextField":
            return .textField
        case "AXTextArea":
            return .textArea
        case "AXSearchField":
            return .searchField
        case "AXSecureTextField":
            return .secureTextField
        case "AXLink":
            return .link
        case "AXCheckBox":
            return .checkbox
        case "AXRadioButton":
            return .radioButton
        case "AXPopUpButton":
            return .popupButton
        case "AXSlider":
            return .slider
        case "AXMenuItem":
            return .menuItem
        case "AXTab":
            return .tab
        case "AXSwitch":
            return .toggle
        default:
            return .unknown
        }
    }

    // MARK: - Accessibility API Helpers

    private func getRole(_ element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &value)
        guard result == .success, let role = value as? String else { return nil }
        return role
    }

    private func getTitle(_ element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &value)
        guard result == .success, let title = value as? String else { return nil }
        return title
    }

    private func getEnabled(_ element: AXUIElement) -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXEnabled" as CFString, &value)
        guard result == .success, let enabled = value as? Bool else { return nil }
        return enabled
    }

    private func getParent(_ element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXParent" as CFString, &value)
        guard result == .success, let parent = value else { return nil }
        return (parent as! AXUIElement)
    }

    private func getChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &value)
        guard result == .success, let children = value as? [AXUIElement] else { return nil }
        return children
    }

    private func getBounds(_ element: AXUIElement) -> CGRect? {
        // Get position
        var posValue: AnyObject?
        let posResult = AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &posValue)
        guard posResult == .success, let posValue = posValue else { return nil }

        var position = CGPoint.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &position)

        // Get size
        var sizeValue: AnyObject?
        let sizeResult = AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeValue)
        guard sizeResult == .success, let sizeValue = sizeValue else { return nil }

        var size = CGSize.zero
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }
}

// MARK: - Helper Extensions

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Accessibility Element Copy Helper

private func copyElementAtPosition(
    _ application: AXUIElement,
    _ x: Float,
    _ y: Float
) -> AXUIElement? {
    var element: AXUIElement?
    let result = ApplicationServices.AXUIElementCopyElementAtPosition(application, x, y, &element)
    guard result == .success else { return nil }
    return element
}
