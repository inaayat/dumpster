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

// MARK: - Dumpster Fire Package (Default)

struct DumpsterFirePackage: DesignPackage {
    let name = "Dumpster Fire"

    // Pulled from the dumpster fire pin:
    // Teal body, charcoal lid, orange/yellow flames, cream background
    let canvas = Color(hex: "#F5F3F0")      // warm off-white
    let cardBg = Color(hex: "#FFFFFF")
    let cardAlt = Color(hex: "#F0EFED")
    let sidebarBg = Color(hex: "#2D2D2D")   // charcoal (the lid)

    let textPrimary = Color(hex: "#1A1A1A")
    let textSecondary = Color(hex: "#3A3A3A")
    let textMuted = Color(hex: "#8A8A8A")
    let sidebarText = Color(hex: "#FFFFFF")
    let sidebarMuted = Color(hex: "#A0A0A0")

    let border = Color(hex: "#E5E3E0")
    let divider = Color(hex: "#E5E3E0")
    let cardBorder = Color(hex: "#E5E3E0")

    // Action = flame orange (urgent, hot, do it now)
    let actionColor = Color(hex: "#F15A24")
    let actionTint = Color(hex: "#FDDCCC")
    // Brainstorm = teal (the dumpster body — ideas live here)
    let brainstormColor = Color(hex: "#2D8A7E")
    let brainstormTint = Color(hex: "#D0F0EC")
    // Resource = warm purple (collected, saved, referenced)
    let resourceColor = Color(hex: "#7B68EE")
    let resourceTint = Color(hex: "#E0DBFC")

    // Primary accent = teal (the dumpster itself)
    let accent = Color(hex: "#3BA99C")
    let accentTint = Color(hex: "#C5E8E4")
    // Warning/wins = flame yellow
    let warnColor = Color(hex: "#F7941D")
    let successColor = Color(hex: "#2D8A7E")

    let cornerRadius: CGFloat = 10
    let cardPadding: CGFloat = 14
    let sectionSpacing: CGFloat = 20
    let itemSpacing: CGFloat = 8

    let colorScheme: ColorScheme? = .light
}

// MARK: - Bro Package (Dark — dumpster at night)

struct BroPackage: DesignPackage {
    let name = "Bro"

    // Dark charcoal base — like the dumpster lid
    let canvas = Color(hex: "#1C1C1E")
    let cardBg = Color(hex: "#2C2C2E")
    let cardAlt = Color(hex: "#3A3A3C")
    let sidebarBg = Color(hex: "#141414")

    let textPrimary = Color(hex: "#F0F0F0")
    let textSecondary = Color(hex: "#C8C8C8")
    let textMuted = Color(hex: "#7A7A7A")
    let sidebarText = Color(hex: "#FFFFFF")
    let sidebarMuted = Color(hex: "#8A8A8A")

    let border = Color(hex: "#3A3A3C")
    let divider = Color(hex: "#3A3A3C")
    let cardBorder = Color(hex: "#444446")

    // Colors glow against dark — keep them vibrant
    let actionColor = Color(hex: "#FF6B35")
    let actionTint = Color(hex: "#3D2518")
    let brainstormColor = Color(hex: "#3BA99C")
    let brainstormTint = Color(hex: "#1A3230")
    let resourceColor = Color(hex: "#9B8AFB")
    let resourceTint = Color(hex: "#2A2540")

    let accent = Color(hex: "#3BA99C")
    let accentTint = Color(hex: "#1A3230")
    let warnColor = Color(hex: "#FFB347")
    let successColor = Color(hex: "#3BA99C")

    let cornerRadius: CGFloat = 10
    let cardPadding: CGFloat = 14
    let sectionSpacing: CGFloat = 20
    let itemSpacing: CGFloat = 8

    let colorScheme: ColorScheme? = .dark
}

// MARK: - Theme (Active Package Accessor)

enum Theme {
    static var activePackage: DesignPackage = DumpsterFirePackage()

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

// MARK: - Font Extension

extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String = switch weight {
        case .bold: "Satoshi-Bold"
        case .semibold: "Satoshi-Bold"
        case .medium: "Satoshi-Medium"
        case .light: "Satoshi-Light"
        default: "Satoshi-Regular"
        }
        return .custom(name, size: size)
    }
}
