import SwiftUI

// MARK: - Design Package Protocol

protocol DesignPackage {
    var name: String { get }

    // Backgrounds
    var canvas: Color { get }
    var cardBg: Color { get }
    var cardAlt: Color { get }
    var sidebarBg: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textMuted: Color { get }
    var sidebarText: Color { get }
    var sidebarMuted: Color { get }

    // Borders & Dividers
    var border: Color { get }
    var divider: Color { get }
    var cardBorder: Color { get }

    // Category Colors
    var actionColor: Color { get }
    var actionTint: Color { get }
    var brainstormColor: Color { get }
    var brainstormTint: Color { get }
    var resourceColor: Color { get }
    var resourceTint: Color { get }

    // Accents
    var accent: Color { get }
    var accentTint: Color { get }
    var warnColor: Color { get }
    var successColor: Color { get }

    // Geometry
    var cornerRadius: CGFloat { get }
    var cardPadding: CGFloat { get }
    var sectionSpacing: CGFloat { get }
    var itemSpacing: CGFloat { get }

    // Color scheme override
    var colorScheme: ColorScheme? { get }
}

// MARK: - Warm Package (Default)

struct WarmPackage: DesignPackage {
    let name = "Warm"

    let canvas = Color(hex: "#F5EFE6")
    let cardBg = Color(hex: "#FFFFFF")
    let cardAlt = Color(hex: "#F9F9F7")
    let sidebarBg = Color(hex: "#0F0F10")

    let textPrimary = Color(hex: "#0F0F10")
    let textSecondary = Color(hex: "#2A2A2A")
    let textMuted = Color(hex: "#7A7A7A")
    let sidebarText = Color(hex: "#FFFFFF")
    let sidebarMuted = Color(hex: "#9A9A9A")

    let border = Color(hex: "#E6E0D6")
    let divider = Color(hex: "#E6E0D6")
    let cardBorder = Color.clear

    let actionColor = Color(hex: "#7E944F")
    let actionTint = Color(hex: "#C9D7A3")
    let brainstormColor = Color(hex: "#C85A8E")
    let brainstormTint = Color(hex: "#F4B6D3")
    let resourceColor = Color(hex: "#6E8FBC")
    let resourceTint = Color(hex: "#C9D8EF")

    let accent = Color(hex: "#A75A8A")
    let accentTint = Color(hex: "#F4B6D3")
    let warnColor = Color(hex: "#C7A73E")
    let successColor = Color(hex: "#7E944F")

    let cornerRadius: CGFloat = 10
    let cardPadding: CGFloat = 14
    let sectionSpacing: CGFloat = 20
    let itemSpacing: CGFloat = 8

    let colorScheme: ColorScheme? = .light
}

// MARK: - Bro Package (Dark/System)

struct BroPackage: DesignPackage {
    let name = "Bro"

    var canvas: Color { Color(nsColor: .windowBackgroundColor) }
    var cardBg: Color { Color(nsColor: .controlBackgroundColor) }
    let cardAlt = Color(hex: "#3A3A3C")
    let sidebarBg = Color(hex: "#0F0F10")

    var textPrimary: Color { Color(nsColor: .labelColor) }
    var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }
    var textMuted: Color { Color(nsColor: .tertiaryLabelColor) }
    let sidebarText = Color(hex: "#FFFFFF")
    let sidebarMuted = Color(hex: "#9A9A9A")

    var border: Color { Color(nsColor: .separatorColor) }
    var divider: Color { Color(nsColor: .separatorColor) }
    var cardBorder: Color { Color(nsColor: .separatorColor) }

    var actionColor: Color { Color(nsColor: .secondaryLabelColor) }
    let actionTint = Color(hex: "#2C2C2E")
    var brainstormColor: Color { Color(nsColor: .secondaryLabelColor) }
    let brainstormTint = Color(hex: "#2C2C2E")
    var resourceColor: Color { Color(nsColor: .secondaryLabelColor) }
    let resourceTint = Color(hex: "#2C2C2E")

    var accent: Color { Color(nsColor: .secondaryLabelColor) }
    let accentTint = Color(hex: "#2C2C2E")
    var warnColor: Color { Color(nsColor: .secondaryLabelColor) }
    var successColor: Color { Color(nsColor: .secondaryLabelColor) }

    let cornerRadius: CGFloat = 10
    let cardPadding: CGFloat = 14
    let sectionSpacing: CGFloat = 20
    let itemSpacing: CGFloat = 8

    let colorScheme: ColorScheme? = .dark
}

// MARK: - Theme (Active Package Accessor)

enum Theme {
    static var activePackage: DesignPackage = WarmPackage()

    static var isBro: Bool { UserDefaults.standard.bool(forKey: "broMode") }

    private static var pkg: DesignPackage {
        isBro ? BroPackage() : activePackage
    }

    // Backgrounds
    static var canvas: Color { pkg.canvas }
    static var cardBg: Color { pkg.cardBg }
    static var cardAlt: Color { pkg.cardAlt }
    static var sidebarBg: Color { pkg.sidebarBg }

    // Text
    static var textPrimary: Color { pkg.textPrimary }
    static var textSecondary: Color { pkg.textSecondary }
    static var textMuted: Color { pkg.textMuted }
    static var sidebarText: Color { pkg.sidebarText }
    static var sidebarMuted: Color { pkg.sidebarMuted }

    // Borders
    static var border: Color { pkg.border }
    static var divider: Color { pkg.divider }
    static var cardBorder: Color { pkg.cardBorder }

    // Category
    static var actionColor: Color { pkg.actionColor }
    static var actionTint: Color { pkg.actionTint }
    static var brainstormColor: Color { pkg.brainstormColor }
    static var brainstormTint: Color { pkg.brainstormTint }
    static var resourceColor: Color { pkg.resourceColor }
    static var resourceTint: Color { pkg.resourceTint }

    // Accents
    static var accent: Color { pkg.accent }
    static var accentTint: Color { pkg.accentTint }
    static var warnColor: Color { pkg.warnColor }
    static var successColor: Color { pkg.successColor }

    // Geometry
    static var cornerRadius: CGFloat { pkg.cornerRadius }
    static var cardPadding: CGFloat { pkg.cardPadding }
    static var sectionSpacing: CGFloat { pkg.sectionSpacing }
    static var itemSpacing: CGFloat { pkg.itemSpacing }

    // Color scheme
    static var colorScheme: ColorScheme? { pkg.colorScheme }

    // Helpers
    static func categoryColor(_ category: Category) -> Color {
        switch category {
        case .action: return actionColor
        case .brainstorm: return brainstormColor
        case .resource: return resourceColor
        }
    }

    static func categoryTint(_ category: Category) -> Color {
        switch category {
        case .action: return actionTint
        case .brainstorm: return brainstormTint
        case .resource: return resourceTint
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

// MARK: - Inter Font Extension

extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String = switch weight {
        case .bold: "Inter-Bold"
        case .semibold: "Inter-SemiBold"
        case .medium: "Inter-Medium"
        default: "Inter-Regular"
        }
        return .custom(name, size: size)
    }
}
