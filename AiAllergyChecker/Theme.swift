//
//  Theme.swift
//  AiAllergyChecker
//
//  「Allergen Monitor」テーマの配色（Android 版と同じ値）。
//

import SwiftUI

extension Color {
    /// 0xAARRGGBB / 0xRRGGBB
    init(hex: UInt32, alpha: Double? = nil) {
        let hasAlpha = hex > 0xFFFFFF
        let a = alpha ?? (hasAlpha ? Double((hex >> 24) & 0xFF) / 255 : 1)
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: a)
    }
}

enum Theme {
    static let chipBgOff      = Color(hex: 0x161B22)
    static let chipStrokeOff  = Color(hex: 0x262C36)
    static let chipBgOnStart  = Color(hex: 0xFF3B30)
    static let chipBgOnEnd    = Color(hex: 0xB0001C)
    static let chipStrokeOn   = Color(hex: 0xFF8A80)
    static let textOff        = Color(hex: 0xC9D1D9)
    static let textSubOff     = Color(hex: 0x6E7681)
    static let textMain       = Color(hex: 0xE6EDF3)
    static let textMuted      = Color(hex: 0x8B949E)
    static let ledScan        = Color(hex: 0x3FB950)
    static let ledAlert       = Color(hex: 0xFF3B30)
    static let accentRed      = Color(hex: 0xFF6B6B)
    static let accentAmber    = Color(hex: 0xFFC857)
    static let red            = Color(hex: 0xFF3B30)
    static let panelTop       = Color(hex: 0x11161D)
    static let panelBottom    = Color(hex: 0x080B10)
    static let cardBg         = Color(hex: 0x161B22)
    static let cardStroke     = Color(hex: 0x30363D)
    static let buttonBg       = Color(hex: 0x21262D)

    static func categoryColor(_ c: AllergenCategory) -> Color {
        switch c {
        case .basic:   return Color(hex: 0xFF5A5F)
        case .meat:    return Color(hex: 0xFF8A65)
        case .seafood: return Color(hex: 0x4FC3F7)
        case .nuts:    return Color(hex: 0xD7B377)
        case .fruit:   return Color(hex: 0x9CCC65)
        case .other:   return Color(hex: 0xB39DDB)
        }
    }
}

// MARK: - Toast

struct ToastOverlay: ViewModifier {
    let toast: ToastMessage?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast {
                Text(toast.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id(toast.id)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toast)
    }
}

extension View {
    func toast(_ toast: ToastMessage?) -> some View { modifier(ToastOverlay(toast: toast)) }
}
