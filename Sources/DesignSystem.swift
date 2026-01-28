import Cocoa

/// Centralized design system for berrry-joyful
/// Provides consistent colors, typography, spacing, and visual styles
enum DesignSystem {

    // MARK: - Colors

    /// Semantic colors that automatically adapt to light/dark mode
    enum Colors {
        // Backgrounds
        static let background = NSColor.windowBackgroundColor
        static let secondaryBackground = NSColor.controlBackgroundColor
        static let tertiaryBackground = NSColor.underPageBackgroundColor

        // Text
        static let text = NSColor.labelColor
        static let secondaryText = NSColor.secondaryLabelColor
        static let tertiaryText = NSColor.tertiaryLabelColor
        static let quaternaryText = NSColor.quaternaryLabelColor

        // Controls
        static let accent = NSColor.controlAccentColor
        static let control = NSColor.controlColor
        static let selectedContent = NSColor.selectedContentBackgroundColor

        // Separators & Borders
        static let separator = NSColor.separatorColor
        static let gridLine = NSColor.gridColor

        // Status colors
        static let success = NSColor.systemGreen
        static let warning = NSColor.systemOrange
        static let error = NSColor.systemRed
        static let info = NSColor.systemBlue

        // Custom app colors
        static let debugBackground = NSColor(white: 0.1, alpha: 1.0)
        static let debugText = NSColor(white: 0.85, alpha: 1.0)
    }

    // MARK: - Typography

    /// Consistent font sizes and weights
    enum Typography {
        // Display (large titles)
        static let displayLarge = NSFont.systemFont(ofSize: 20, weight: .bold)
        static let displayMedium = NSFont.systemFont(ofSize: 18, weight: .bold)

        // Headlines (section titles)
        static let headlineLarge = NSFont.systemFont(ofSize: 16, weight: .semibold)
        static let headlineMedium = NSFont.systemFont(ofSize: 14, weight: .semibold)
        static let headlineSmall = NSFont.systemFont(ofSize: 13, weight: .semibold)

        // Body text
        static let bodyLarge = NSFont.systemFont(ofSize: 13, weight: .regular)
        static let bodyMedium = NSFont.systemFont(ofSize: 12, weight: .regular)
        static let bodySmall = NSFont.systemFont(ofSize: 11, weight: .regular)

        // Captions and small text
        static let caption = NSFont.systemFont(ofSize: 10, weight: .regular)

        // Monospace (for code/debug)
        static let codeLarge = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        static let codeMedium = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        static let codeSmall = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    }

    // MARK: - Spacing

    /// Consistent spacing scale (8pt grid system)
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radius

    /// Standard corner radii for UI elements
    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }

    // MARK: - Shadows

    /// Standard shadow configurations
    enum Shadow {
        struct Config {
            let color: NSColor
            let opacity: Float
            let radius: CGFloat
            let offset: CGSize
        }

        static let subtle = Config(
            color: .black,
            opacity: 0.05,
            radius: 2,
            offset: CGSize(width: 0, height: 1)
        )

        static let card = Config(
            color: .black,
            opacity: 0.1,
            radius: 4,
            offset: CGSize(width: 0, height: 2)
        )

        static let elevated = Config(
            color: .black,
            opacity: 0.15,
            radius: 8,
            offset: CGSize(width: 0, height: 4)
        )
    }

    // MARK: - Layout Constants

    enum Layout {
        // Window sizes
        static let defaultWindowWidth: CGFloat = 800
        static let defaultWindowHeight: CGFloat = 700

        // Header
        static let headerHeight: CGFloat = 50

        // Common component sizes
        static let buttonHeight: CGFloat = 24
        static let sliderWidth: CGFloat = 300
        static let labelWidth: CGFloat = 100
        static let popupButtonWidth: CGFloat = 150

        // Debug log
        static let debugLogDefaultHeight: CGFloat = 200
        static let debugLogMinHeight: CGFloat = 100
    }

    // MARK: - Helper Methods

    /// Apply card style to an NSBox
    static func styleAsCard(_ box: NSBox, cornerRadius: CGFloat = CornerRadius.large) {
        box.boxType = .custom
        box.borderType = .lineBorder
        box.borderWidth = 1
        box.borderColor = Colors.separator
        box.cornerRadius = cornerRadius
        box.fillColor = Colors.secondaryBackground
        box.contentViewMargins = NSSize(width: Spacing.md, height: Spacing.md)
    }

    /// Apply section box style (for grouping controls)
    static func styleAsSectionBox(_ box: NSBox, title: String? = nil) -> NSView {
        box.boxType = .custom
        box.borderType = .lineBorder
        box.borderWidth = 1
        box.borderColor = Colors.separator
        box.cornerRadius = CornerRadius.large
        box.fillColor = Colors.secondaryBackground
        box.contentViewMargins = NSSize(width: Spacing.md, height: Spacing.md)

        if let title = title {
            box.title = title
            box.titlePosition = .atTop
        }

        return box
    }

    /// Apply shadow to a layer
    static func applyShadow(_ shadow: Shadow.Config, to layer: CALayer) {
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOpacity = shadow.opacity
        layer.shadowRadius = shadow.radius
        layer.shadowOffset = shadow.offset
    }

    /// Create a section header label
    static func createSectionHeader(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = Typography.headlineMedium
        label.textColor = Colors.text
        return label
    }

    /// Create a standard label
    static func createLabel(_ text: String, style: LabelStyle = .body) -> NSTextField {
        let label = NSTextField(labelWithString: text)

        switch style {
        case .body:
            label.font = Typography.bodyMedium
            label.textColor = Colors.text
        case .secondary:
            label.font = Typography.bodySmall
            label.textColor = Colors.secondaryText
        case .caption:
            label.font = Typography.caption
            label.textColor = Colors.tertiaryText
        case .code:
            label.font = Typography.codeMedium
            label.textColor = Colors.secondaryText
        }

        return label
    }

    enum LabelStyle {
        case body
        case secondary
        case caption
        case code
    }

    /// Create a section box with content
    static func createSectionBox(title: String, content: NSView) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.borderType = .lineBorder
        box.borderWidth = 1
        box.borderColor = Colors.separator
        box.cornerRadius = CornerRadius.large
        box.fillColor = Colors.secondaryBackground
        box.contentViewMargins = NSSize(width: Spacing.md, height: Spacing.md)

        let header = createSectionHeader(title)

        let stack = NSStackView(views: [header, content])
        stack.orientation = .vertical
        stack.spacing = Spacing.sm
        stack.alignment = .leading

        box.contentView = stack
        return box
    }

    // MARK: - System Settings Style (Flat)

    /// Create a flat section divider (System Settings style)
    static func createSectionDivider(width: CGFloat) -> NSBox {
        let divider = NSBox(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        divider.boxType = .separator
        divider.autoresizingMask = [.width]
        return divider
    }

    /// Create a section header for flat layout (System Settings style)
    static func createFlatSectionHeader(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = Typography.headlineMedium
        label.textColor = Colors.text
        label.frame = frame
        label.autoresizingMask = [.width]
        return label
    }

    /// Create a horizontal row with label and control (System Settings style)
    /// Returns a container view with the label on left and control on right
    static func createHorizontalRow(
        label: String,
        control: NSView,
        width: CGFloat,
        height: CGFloat = 32,
        labelWidth: CGFloat = 240,
        description: String? = nil
    ) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.autoresizingMask = [.width]

        // Label on left
        let labelView = NSTextField(labelWithString: label)
        labelView.font = Typography.bodyMedium
        labelView.textColor = Colors.text
        labelView.alignment = .left
        labelView.frame = NSRect(x: Spacing.lg, y: (height - 20) / 2, width: labelWidth, height: 20)
        labelView.autoresizingMask = [.maxXMargin]
        container.addSubview(labelView)

        // Control on right
        control.frame.origin = NSPoint(x: Spacing.lg + labelWidth + Spacing.md, y: (height - control.frame.height) / 2)
        control.autoresizingMask = [.minXMargin]
        container.addSubview(control)

        // Optional description text below
        if let desc = description {
            let descLabel = NSTextField(wrappingLabelWithString: desc)
            descLabel.font = Typography.caption
            descLabel.textColor = Colors.secondaryText
            descLabel.alignment = .left
            descLabel.frame = NSRect(x: Spacing.lg, y: 0, width: width - Spacing.lg * 2, height: 16)
            descLabel.autoresizingMask = [.width]

            // Adjust container height to fit description
            container.frame.size.height = height + 20
            descLabel.frame.origin.y = 4
            labelView.frame.origin.y = height - 16
            control.frame.origin.y = height - 20

            container.addSubview(descLabel)
        }

        return container
    }

    /// Create a flat section (System Settings style - no box, no shadow)
    /// Just groups related controls with a header and optional background
    static func createFlatSection(
        title: String,
        rows: [NSView],
        width: CGFloat,
        backgroundColor: NSColor? = nil
    ) -> NSView {
        var y: CGFloat = 0

        // Calculate total height
        let totalHeight = Spacing.lg + 24 + Spacing.sm + rows.reduce(0) { $0 + $1.frame.height + Spacing.xs } + Spacing.md

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: totalHeight))
        container.autoresizingMask = [.width]

        // Optional subtle background
        if let bgColor = backgroundColor {
            container.wantsLayer = true
            container.layer?.backgroundColor = bgColor.cgColor
            container.layer?.cornerRadius = CornerRadius.medium
        }

        y = totalHeight - Spacing.lg

        // Section header
        let header = createFlatSectionHeader(title, frame: NSRect(x: Spacing.lg, y: y - 24, width: width - Spacing.lg * 2, height: 24))
        container.addSubview(header)
        y -= 24 + Spacing.sm

        // Add all rows
        for row in rows {
            y -= row.frame.height
            row.frame.origin = NSPoint(x: 0, y: y)
            container.addSubview(row)
            y -= Spacing.xs
        }

        return container
    }
}
