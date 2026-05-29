import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum CBColors {
    // Neutrals
    static let bg      = Color.dynamic(light: 0xffffff, dark: 0x0f1115)
    static let bgSoft  = Color.dynamic(light: 0xfafaf9, dark: 0x171a20)
    static let ink     = Color.dynamic(light: 0x111827, dark: 0xf7f7f2)
    static let inkMid  = Color.dynamic(light: 0x6b7280, dark: 0xb7bdc8)
    static let inkFaint = Color.dynamic(light: 0xe5e7eb, dark: 0x343941)
    static let inkLine  = Color.dynamic(light: 0xf0f0ef, dark: 0x242830)

    // Primary accent — Indigo (replaces orange terra)
    static let terra  = Color.dynamic(light: 0x4338CA, dark: 0x818CF8)  // "terra" kept for naming compat

    // Success / ARKit-ready indicator
    static let sage   = Color.dynamic(light: 0x1a7a48, dark: 0x55c985)

    // Macro — carbs
    static let ocean  = Color.dynamic(light: 0x1d55a0, dark: 0x70aef4)

    // Macro — fat  (amber, less orange-heavy)
    static let gold   = Color.dynamic(light: 0x9a6414, dark: 0xd4a030)

    // Macro — protein
    static let plum   = Color.dynamic(light: 0x6d3bbd, dark: 0xb39cff)

    // Controls
    static let controlFill    = Color.dynamic(light: 0x4338CA, dark: 0x818CF8)
    static let controlOnFill  = Color.dynamic(light: 0xffffff, dark: 0x0f1115)

    static func nutrition(_ key: NutritionColorKey) -> Color {
        switch key {
        case .terra: terra
        case .sage:  sage
        case .ocean: ocean
        case .gold:  gold
        case .plum:  plum
        case .ink:   inkFaint
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >>  8) & 0xff) / 255,
                  blue:  Double( hex        & 0xff) / 255,
                  opacity: alpha)
    }

    static func dynamic(light: UInt, dark: UInt, alpha: Double = 1.0) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { t in
            UIColor(hex: t.userInterfaceStyle == .dark ? dark : light, alpha: alpha)
        })
        #else
        return Color(hex: light, alpha: alpha)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        self.init(red:   CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >>  8) & 0xff) / 255,
                  blue:  CGFloat( hex        & 0xff) / 255,
                  alpha: CGFloat(alpha))
    }
}
#endif
