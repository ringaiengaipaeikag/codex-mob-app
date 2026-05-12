//
//  DesignSystem.swift
//
//  REGHelp 2.0 · iOS port of the web design system defined in
//  /improvements/shared.css. Mirrors:
//    - Deep Indigo primary  (--p50 … --p950, main = #4f46e5)
//    - Cyan secondary       (--s500 = #06b6d4)
//    - Pink warm accent     (--a500 = #ec4899, used ≤5% of surface)
//    - Gray neutral scale   (--g50 … --g950)
//    - Semantic: green/red/yellow/purple
//    - Shadows: card / card-hover / navbar / dropdown-lg / modal
//    - Motion: 3 durations (200/300/350 ms) × 2 easings (out, in-out)
//    - Fonts: Montserrat (body) + JetBrains Mono (code/kicker/tags)
//
//  Montserrat / JetBrains Mono аренда требует TTF в bundle + UIAppFonts.
//  Пока файлы не подключены — функции font(_:) фолбэкают на системные
//  аналоги, но контракт остаётся тем же, что и в CSS.
//

import SwiftUI

// MARK: - Hex + scheme-aware color

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
    static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { t in
            let hex = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red:   CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >>  8) & 0xFF) / 255.0,
                blue:  CGFloat( hex        & 0xFF) / 255.0,
                alpha: 1
            )
        })
    }
}

// MARK: - Design tokens

enum DS {

    // ===== Palette (точные значения из shared.css) =====
    enum P {
        // Primary — Deep Indigo
        static let p50  = Color(hex: 0xEEF2FF)
        static let p100 = Color(hex: 0xE0E7FF)
        static let p200 = Color(hex: 0xC7D2FE)
        static let p300 = Color(hex: 0xA5B4FC)
        static let p400 = Color(hex: 0x818CF8)
        static let p500 = Color(hex: 0x6366F1)
        static let p600 = Color(hex: 0x4F46E5)   // main
        static let p700 = Color(hex: 0x4338CA)   // hover
        static let p800 = Color(hex: 0x3730A3)
        static let p900 = Color(hex: 0x312E81)
        static let p950 = Color(hex: 0x1E1B4B)

        // Secondary — Cyan
        static let s50  = Color(hex: 0xECFEFF)
        static let s100 = Color(hex: 0xCFFAFE)
        static let s200 = Color(hex: 0xA5F3FC)
        static let s400 = Color(hex: 0x22D3EE)
        static let s500 = Color(hex: 0x06B6D4)
        static let s600 = Color(hex: 0x0891B2)
        static let s700 = Color(hex: 0x0E7490)
        static let s800 = Color(hex: 0x155E75)

        // Warm accent — Pink 500
        static let a50  = Color(hex: 0xFDF2F8)
        static let a100 = Color(hex: 0xFCE7F3)
        static let a200 = Color(hex: 0xFBCFE8)
        static let a400 = Color(hex: 0xF472B6)
        static let a500 = Color(hex: 0xEC4899)
        static let a600 = Color(hex: 0xDB2777)
        static let a700 = Color(hex: 0xBE185D)
        static let a800 = Color(hex: 0x9D174D)

        // Neutral
        static let g50  = Color(hex: 0xF9FAFB)
        static let g100 = Color(hex: 0xF3F4F6)
        static let g200 = Color(hex: 0xE5E7EB)
        static let g300 = Color(hex: 0xD1D5DB)
        static let g400 = Color(hex: 0x9CA3AF)
        static let g500 = Color(hex: 0x6B7280)
        static let g600 = Color(hex: 0x4B5563)
        static let g700 = Color(hex: 0x374151)
        static let g800 = Color(hex: 0x1F2937)
        static let g900 = Color(hex: 0x111827)
        static let g950 = Color(hex: 0x030712)

        // Semantic
        static let green  = Color(hex: 0x16A34A)
        static let red    = Color(hex: 0xDC2626)
        static let yellow = Color(hex: 0xEAB308)
        static let purple = Color(hex: 0x9333EA)
    }

    // ===== Surface tokens (dark-mode aware) =====
    static var bg: Color          { .dyn(light: 0xFFFFFF, dark: 0x030712) } // body
    static var bgSubtle: Color    { .dyn(light: 0xF9FAFB, dark: 0x111827) } // g50/g900
    static var surface: Color     { .dyn(light: 0xFFFFFF, dark: 0x1F2937) } // card
    static var surfaceAlt: Color  { .dyn(light: 0xF9FAFB, dark: 0x111827) }
    static var surfaceInset: Color{ .dyn(light: 0xF3F4F6, dark: 0x374151) }
    static var hairline: Color    { .dyn(light: 0xF3F4F6, dark: 0x1F2937) } // g100 (use for cards)
    static var hairlineMid: Color { .dyn(light: 0xE5E7EB, dark: 0x374151) }
    static var hairlineStrong: Color { .dyn(light: 0xD1D5DB, dark: 0x4B5563) }
    static var ink: Color         { .dyn(light: 0x111827, dark: 0xF9FAFB) } // g900 / g50
    static var inkDim: Color      { .dyn(light: 0x4B5563, dark: 0xD1D5DB) } // g600 / g300
    static var inkMuted: Color    { .dyn(light: 0x6B7280, dark: 0x9CA3AF) } // g500 / g400
    static var inkFaint: Color    { .dyn(light: 0x9CA3AF, dark: 0x6B7280) } // g400 / g500

    static var primary: Color     { P.p600 }
    static var primaryHover: Color{ P.p700 }
    static var secondary: Color   { P.s500 }
    static var accent: Color      { P.a500 }

    // ===== Brand gradient (for heading spans, avatars) =====
    static let brandGradient = LinearGradient(
        colors: [P.p600, P.s500],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let avatarGradient = LinearGradient(
        colors: [P.p500, P.s500],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // ===== Radius =====
    static let rSm: CGFloat = 4       // tag
    static let rMd: CGFloat = 6       // small button
    static let rLg: CGFloat = 8       // button
    static let rXl: CGFloat = 12      // card
    static let r2Xl: CGFloat = 14     // palette modal
    static let r3Xl: CGFloat = 16     // hero card
    static let rFull: CGFloat = 9999  // pill

    // ===== Spacing (Tailwind 4px scale) =====
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
    static let s10: CGFloat = 40
    static let s12: CGFloat = 48
    static let s16: CGFloat = 64

    // ===== Motion =====
    static let dFast: Double = 0.2
    static let dBase: Double = 0.3
    static let dSlow: Double = 0.35
    // SwiftUI aналог cubic-bezier(.16,1,.3,1) — практически эквивалент easeOut.
    static let easeOut = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: dBase)
    static let easeOutFast = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: dFast)
    static let easeInOut = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: dBase)

    // ===== Typography =====
    // Пока TTF не подключены — fallback на системные. Контракт не ломается.
    private static let hasMontserrat: Bool = {
        UIFont.familyNames.contains("Montserrat")
    }()
    private static let hasJBMono: Bool = {
        UIFont.familyNames.contains { $0.lowercased().contains("jetbrains mono") }
    }()

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if hasMontserrat {
            return .custom("Montserrat", size: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if hasJBMono {
            return .custom("JetBrainsMono-Regular", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    // ===== Type scale =====
    static var tHero: Font   { body(36, weight: .heavy) }
    static var tH1: Font     { body(30, weight: .heavy) }
    static var tH2: Font     { body(24, weight: .bold) }
    static var tH3: Font     { body(20, weight: .bold) }
    static var tH4: Font     { body(18, weight: .semibold) }
    static var tLead: Font   { body(16) }
    static var tBody: Font   { body(14) }
    static var tSm: Font     { body(13) }
    static var tXs: Font     { body(12) }
    static var tLabel: Font  { body(14, weight: .medium) }
    static var tButton: Font { body(14, weight: .medium) }

    static var tKicker: Font { mono(12, weight: .medium) }   // JB Mono 12, 0.12em tracking
    static var tTag: Font    { mono(11, weight: .medium) }
    static var tTagSm: Font  { mono(10, weight: .medium) }
    static var tCode: Font   { mono(13) }
    static var tCodeSm: Font { mono(12) }
    static var tCodeXs: Font { mono(11) }
}

// MARK: - Shadow helpers

extension View {
    func shadowCard()      -> some View { shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1) }
    func shadowCardHover() -> some View { shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6) }
    func shadowDropdown()  -> some View { shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10) }
    func shadowModal()     -> some View { shadow(color: .black.opacity(0.25), radius: 40, x: 0, y: 20) }
    func shadowNavbar()    -> some View { shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1) }
}

// MARK: - Chip colors (pill-chips in REGHelp: chip-i / chip-g / chip-a)

enum ChipColor {
    case indigo, green, accent, gray, cyan, red, yellow, purple, orange

    var bg: Color {
        switch self {
        case .indigo: return .dyn(light: 0xE0E7FF, dark: 0x312E81) // p100 / p900
        case .green:  return .dyn(light: 0xDCFCE7, dark: 0x052E16)
        case .accent: return .dyn(light: 0xFCE7F3, dark: 0x500724) // a100 / pink-950
        case .gray:   return .dyn(light: 0xF3F4F6, dark: 0x374151)
        case .cyan:   return .dyn(light: 0xCFFAFE, dark: 0x164E63)
        case .red:    return .dyn(light: 0xFEE2E2, dark: 0x450A0A)
        case .yellow: return .dyn(light: 0xFEF9C3, dark: 0x422006)
        case .purple: return .dyn(light: 0xF3E8FF, dark: 0x3B0764)
        case .orange: return .dyn(light: 0xFED7AA, dark: 0x431407)
        }
    }
    var fg: Color {
        switch self {
        case .indigo: return .dyn(light: 0x4338CA, dark: 0xA5B4FC) // p700 / p300
        case .green:  return .dyn(light: 0x15803D, dark: 0x86EFAC)
        case .accent: return .dyn(light: 0xBE185D, dark: 0xF9A8D4) // a700 / pink-300
        case .gray:   return .dyn(light: 0x4B5563, dark: 0xD1D5DB)
        case .cyan:   return .dyn(light: 0x0E7490, dark: 0x67E8F9)
        case .red:    return .dyn(light: 0xB91C1C, dark: 0xFCA5A5)
        case .yellow: return .dyn(light: 0xA16207, dark: 0xFDE68A)
        case .purple: return .dyn(light: 0x7E22CE, dark: 0xD8B4FE)
        case .orange: return .dyn(light: 0x9A3412, dark: 0xFDBA74)
        }
    }
}

// MARK: - REGHelp building blocks

/// `.kicker` — JB Mono, 12px, letter-spacing 0.12em, uppercase, indigo.
struct RKicker: View {
    let text: String
    var color: Color = DS.primary
    var body: some View {
        Text(text.uppercased())
            .font(DS.tKicker)
            .tracking(1.4)   // ≈ 0.12em at 12px
            .foregroundStyle(color)
    }
}

/// `.chip` — pill, 999px, Mono-ish font 12/semibold, tinted bg.
struct RChip: View {
    let text: String
    var color: ChipColor = .indigo
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            }
            Text(text).font(DS.body(12, weight: .semibold))
        }
        .foregroundStyle(color.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous).fill(color.bg)
        )
    }
}

/// `.tag` — 4px radius, JB Mono 10-11px, gray bg. Used in card footers.
struct RTag: View {
    let text: String
    var color: ChipColor = .gray
    var body: some View {
        Text(text)
            .font(DS.tTagSm)
            .foregroundStyle(color.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: DS.rSm, style: .continuous).fill(color.bg)
            )
    }
}

/// `.card` — bg white, 1px g100 border, radius 12-16, shadow-card.
struct RCard<Content: View>: View {
    var padding: CGFloat = DS.s6
    var radius: CGFloat = DS.rXl
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(DS.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DS.hairline, lineWidth: 1)
            )
            .shadowCard()
    }
}

/// Buttons: primary (p600), outline, ghost, pink (accent), dark, danger.
enum RButtonVariant { case primary, outline, ghost, pink, dark, danger, dangerOutline, success }
enum RButtonSize {
    case sm, md, lg
    // +20% размер относительно Flowbite-baseline. Пользователь просил чтобы
    // кнопки были крупнее — применяется и к RButton, и к FBButton (тот
    // делегирует сюда). Cтарые значения в комментариях для отката:
    // sm: 12/6/12   md: 16/10/tButton(13)   lg: 20/12/15
    var hPad: CGFloat { switch self { case .sm: return 14; case .md: return 19; case .lg: return 24 } }
    var vPad: CGFloat { switch self { case .sm: return 8;  case .md: return 12; case .lg: return 14 } }
    var font: Font   { switch self { case .sm: return DS.body(14, weight: .medium)
                                    case .md: return DS.body(16, weight: .semibold)
                                    case .lg: return DS.body(18, weight: .medium) } }
}

struct RButton: View {
    let title: String
    var icon: String? = nil
    var variant: RButtonVariant = .primary
    var size: RButtonSize = .md
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    // +20%: 13 → 16 pt, spacing 8 → 10.
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                }
                Text(title).font(size.font)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, size.hPad)
            .padding(.vertical, size.vPad)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .stroke(border, lineWidth: borderWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bg: Color {
        switch variant {
        case .primary:       return DS.P.p600
        case .outline:       return DS.surface
        case .ghost:         return .clear
        case .pink:          return DS.P.a500
        case .dark:          return DS.P.g900
        case .danger:        return DS.P.red
        case .dangerOutline: return .clear
        case .success:       return DS.P.green
        }
    }
    private var fg: Color {
        switch variant {
        case .primary, .pink, .dark, .danger, .success: return .white
        case .outline: return DS.inkDim
        case .ghost:   return DS.inkDim
        case .dangerOutline: return DS.P.red
        }
    }
    private var border: Color {
        switch variant {
        case .outline:        return DS.hairlineMid
        case .dangerOutline:  return DS.P.red
        default:              return .clear
        }
    }
    private var borderWidth: CGFloat {
        variant == .outline || variant == .dangerOutline ? 1 : 0
    }
}

/// Form input — gray-50 bg, 1px g200 border, rounded-lg, g900 text.
struct RField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    var helper: String? = nil
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false
    var mono: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label).font(DS.tLabel).foregroundStyle(DS.inkDim)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .font(mono ? DS.tCode : DS.tBody)
            .foregroundStyle(DS.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous).fill(DS.surfaceAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.rLg, style: .continuous)
                    .stroke(DS.hairlineMid, lineWidth: 1)
            )
            if let helper {
                Text(helper).font(DS.tXs).foregroundStyle(DS.inkMuted)
            }
        }
    }
}

/// Notes block — p50 bg, p200 border, p900 heading, p800 text.
struct RNotes<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DS.body(14, weight: .semibold))
                .foregroundStyle(DS.P.p900)
            content
                .font(DS.tSm)
                .foregroundStyle(DS.P.p800)
        }
        .padding(DS.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous).fill(DS.P.p50)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous)
                .stroke(DS.P.p200, lineWidth: 1)
        )
    }
}

/// Alert — info/success/warning/danger with icon + tinted bg.
struct RAlert: View {
    enum Kind {
        case info, success, warning, danger
        var color: ChipColor {
            switch self { case .info: return .indigo; case .success: return .green
                         case .warning: return .yellow; case .danger: return .red }
        }
        var icon: String {
            switch self { case .info: return "info.circle.fill"
                         case .success: return "checkmark.circle.fill"
                         case .warning: return "exclamationmark.triangle.fill"
                         case .danger: return "xmark.octagon.fill" }
        }
    }
    let kind: Kind
    let title: String?
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.icon)
                .foregroundStyle(kind.color.fg)
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).font(DS.tLabel).foregroundStyle(kind.color.fg)
                }
                Text(text).font(DS.tSm).foregroundStyle(kind.color.fg)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.rXl, style: .continuous).fill(kind.color.bg)
        )
    }
}

/// Code block — g900 bg, e5e7eb text (like shared.css pre.code), radius 10.
struct RCodeBlock<Content: View>: View {
    var copyable: String? = nil
    var dark: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .font(DS.tCodeSm)
                .textSelection(.enabled)
                .foregroundStyle(dark ? Color(hex: 0xE5E7EB) : DS.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(dark ? DS.P.g900 : DS.surfaceInset)
                )

            if let s = copyable {
                Button {
                    UIPasteboard.general.string = s
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(dark ? Color(hex: 0x9CA3AF) : DS.inkMuted)
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(dark ? Color.white.opacity(0.06) : DS.surface)
                        )
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }
}

/// Keyboard shortcut pill, like `<kbd>` in REGHelp.
struct RKbd: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DS.tTag)
            .foregroundStyle(DS.inkDim)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: DS.rSm, style: .continuous).fill(DS.P.g100)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.rSm, style: .continuous)
                    .stroke(DS.hairlineMid, lineWidth: 1)
            )
    }
}

/// Toggle row with title + subtitle.
struct RToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.tLabel).foregroundStyle(DS.ink)
                if let subtitle {
                    Text(subtitle).font(DS.tXs).foregroundStyle(DS.inkMuted)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn).labelsHidden().tint(DS.primary)
        }
    }
}

/// Brand wordmark with gradient span.
struct RBrand: View {
    var size: CGFloat = 18
    var body: some View {
        HStack(spacing: 4) {
            Text("ACP")
                .font(DS.body(size, weight: .bold))
                .foregroundStyle(DS.brandGradient)
            Text("Chat")
                .font(DS.body(size, weight: .bold))
                .foregroundStyle(DS.ink)
        }
        .tracking(-0.2)
    }
}

/// Avatar with initials on brand gradient.
struct RAvatar: View {
    let initials: String
    var size: CGFloat = 32
    var body: some View {
        Text(initials)
            .font(DS.body(size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(DS.avatarGradient))
    }
}

// MARK: - Legacy aliases (used by other files in the project)

// Bridges the previous Flowbite-named API to the new REGHelp primitives
// without requiring a rewrite across call sites. Remove once all views
// have been migrated to R* components.

typealias BadgeColor = ChipColor

struct FBBadge: View {
    let text: String
    var color: ChipColor = .gray
    var pill: Bool = false
    var uppercase: Bool = false
    var icon: String? = nil
    var body: some View {
        if pill {
            RChip(text: uppercase ? text.uppercased() : text, color: color, icon: icon)
        } else {
            // Rectangular tag fallback.
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
                Text(uppercase ? text.uppercased() : text).font(DS.tTag)
            }
            .foregroundStyle(color.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: DS.rSm, style: .continuous).fill(color.bg)
            )
        }
    }
}

struct FBCard<Content: View>: View {
    var padding: CGFloat = DS.s6
    @ViewBuilder var content: Content
    var body: some View { RCard(padding: padding) { content } }
}

enum FBButtonVariant { case primary, alternative, light, dark, ghost, danger, dangerOutline, success, outlinePrimary }
struct FBButton: View {
    let title: String
    var icon: String? = nil
    var variant: FBButtonVariant = .primary
    var size: Size = .md
    var fullWidth: Bool = false
    let action: () -> Void
    enum Size { case xs, sm, md, lg }
    var body: some View {
        RButton(
            title: title,
            icon: icon,
            variant: {
                switch variant {
                case .primary: return .primary
                case .alternative, .light: return .outline
                case .dark: return .dark
                case .ghost: return .ghost
                case .danger: return .danger
                case .dangerOutline: return .dangerOutline
                case .success: return .success
                case .outlinePrimary: return .outline
                }
            }(),
            size: { switch size { case .xs, .sm: return .sm; case .md: return .md; case .lg: return .lg } }(),
            fullWidth: fullWidth,
            action: action
        )
    }
}

struct FBTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    var helper: String? = nil
    var keyboard: UIKeyboardType = .default
    var secure: Bool = false
    var mono: Bool = false
    var body: some View {
        RField(
            label: label, placeholder: placeholder, text: $text,
            helper: helper, keyboard: keyboard, secure: secure, mono: mono
        )
    }
}

struct FBAlert: View {
    enum Kind { case info, success, warning, danger
        var toR: RAlert.Kind {
            switch self { case .info: return .info; case .success: return .success
                        case .warning: return .warning; case .danger: return .danger }
        }
    }
    let kind: Kind
    let title: String?
    let text: String
    var body: some View { RAlert(kind: kind.toR, title: title, text: text) }
}

struct FBCodeBlock<Content: View>: View {
    var copyable: String? = nil
    @ViewBuilder var content: Content
    var body: some View { RCodeBlock(copyable: copyable, dark: false) { content } }
}

struct FBToggle: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var body: some View { RToggle(title: title, subtitle: subtitle, isOn: $isOn) }
}
