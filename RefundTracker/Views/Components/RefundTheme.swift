import SwiftUI
import UIKit

/// The content layer's visual language: warm paper, ink, hairlines, and a serif
/// used for anything that carries a number. Native navigation floats above it
/// in Liquid Glass, while the content keeps its printed-page restraint.
enum RefundTheme {
    // MARK: - Surfaces

    /// The screen behind everything. A warm bone rather than a neutral grey.
    static let paper = adaptive(light: 0xF5F1EA, dark: 0x0C0B0A)

    /// Raised areas: sheets, panels, and any block that needs to lift a step
    /// off the page.
    static let surface = adaptive(light: 0xFCFAF6, dark: 0x16140F)

    /// A tinted fill for marks, chips, and quiet blocks.
    static let sand = adaptive(light: 0xEAE3D6, dark: 0x221F19)

    // MARK: - Rules

    /// The hairline that does most of the layout work in this design.
    static let line = adaptive(light: 0xDFD8CA, dark: 0x2B2721)

    /// A heavier rule, for the top of a section or a selected state.
    static let lineStrong = adaptive(light: 0xC4BAA9, dark: 0x423C33)

    // MARK: - Ink

    static let ink = adaptive(light: 0x17140F, dark: 0xF1ECE2)
    static let inkSoft = adaptive(light: 0x6E665A, dark: 0xA79E8F)
    static let inkFaint = adaptive(light: 0x9C9484, dark: 0x766E62)

    /// Reversed ink, for text sitting on an ink block.
    static let reverse = adaptive(light: 0xFAF7F1, dark: 0x0C0B0A)

    // MARK: - Signals

    /// Used only where something is late or wrong. Its scarcity is the point.
    static let alert = adaptive(light: 0xA33F2C, dark: 0xDB7E66)

    /// Money that has landed.
    static let success = adaptive(light: 0x566B54, dark: 0x93AD8F)

    /// The width of a rule. Half a point lands on one pixel at @2x and reads
    /// as a hairline at @3x.
    static let hairline: CGFloat = 0.5

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Chrome

/// UIKit controls that live in the content layer. Navigation and tab bars are
/// intentionally left to the system so iOS can render and adapt Liquid Glass.
enum RefundChrome {
    static func apply() {
        UIDatePicker.appearance().tintColor = UIColor(RefundTheme.ink)
    }
}

// MARK: - Backdrop

/// A flat sheet of paper. Kept as a view so every screen opts into the same
/// background without repeating the token.
struct RefundBackdrop: View {
    var body: some View {
        RefundTheme.paper
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Rules

/// A one-pixel rule. `Divider` picks up the system separator colour and inset,
/// which reads grey-blue against warm paper.
struct Hairline: View {
    var color: Color = RefundTheme.line
    var weight: CGFloat = RefundTheme.hairline

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
            .accessibilityHidden(true)
    }
}

/// The vertical counterpart, for splitting a row of figures.
struct VerticalHairline: View {
    var height: CGFloat = 34

    var body: some View {
        Rectangle()
            .fill(RefundTheme.line)
            .frame(width: RefundTheme.hairline, height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Cover marks

/// The saved cover for one return. It deliberately shares the same sand tile
/// as merchant monograms so aggregate merchant rows still belong to the same
/// visual system.
struct RefundCoverMark: View {
    let emoji: String
    var size: CGFloat = 44

    var body: some View {
        Text(emoji)
            // Like the monogram below, the glyph stays tied to the fixed tile
            // rather than Dynamic Type so it cannot clip at larger settings.
            .font(.system(size: size * 0.50))
            .frame(width: size, height: size)
            .background(RefundTheme.sand)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Return cover")
            .accessibilityValue(emoji)
    }
}

/// A serif monogram on a sand tile. Monochrome on purpose: a wall of tinted
/// tiles is the thing this redesign is moving away from.
struct MerchantMark: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Text(monogram)
            // Fixed, not scaled: the tile itself has a fixed frame, so a
            // growing monogram would only clip against it.
            .font(.system(size: size * 0.40, design: .serif))
            .foregroundStyle(RefundTheme.ink)
            .frame(width: size, height: size)
            .background(RefundTheme.sand)
            .accessibilityHidden(true)
    }

    private var monogram: String {
        let letters = name
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap(\.first)
        return letters.isEmpty ? "—" : String(letters).uppercased()
    }
}

// MARK: - Text treatments

/// Small, letterspaced, uppercase — the label style that carries this design.
///
/// The size is scaled rather than fixed: these labels sit at 9–12pt by design,
/// below any built-in text style, so they need `@ScaledMetric` to keep growing
/// with the reader's chosen text size.
private struct EyebrowModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let baseSize: CGFloat
    private let color: Color

    init(size: CGFloat, color: Color) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .caption2)
        baseSize = size
        self.color = color
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold))
            .textCase(.uppercase)
            .tracking(baseSize * 0.13)
            .foregroundStyle(color)
    }
}

/// Serif at an exact size, still tied to Dynamic Type. Display figures are set
/// off the type scale on purpose, so a text style would be the wrong size and
/// a bare point size would not grow at all.
private struct SerifModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, relativeTo textStyle: Font.TextStyle, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: .serif))
    }
}

extension View {
    func eyebrow(
        size: CGFloat = 11,
        color: Color = RefundTheme.inkFaint
    ) -> some View {
        modifier(EyebrowModifier(size: size, color: color))
    }

    func serif(
        _ size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body,
        weight: Font.Weight = .regular
    ) -> some View {
        modifier(
            SerifModifier(size: size, relativeTo: textStyle, weight: weight)
        )
    }
}

// MARK: - Section heading

/// An eyebrow over a rule. Sections announce themselves by typography and a
/// line, not by an icon and a coloured title.
struct RefundSectionHeading: View {
    let title: String
    var trailing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .eyebrow(color: RefundTheme.ink)

                Spacer(minLength: 12)

                if let trailing {
                    Text(trailing)
                        .eyebrow(size: 10)
                }
            }

            Hairline(color: RefundTheme.lineStrong)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

/// A solid ink block with a letterspaced label — the one loud element per
/// screen.
struct RefundPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleOnly)
            .eyebrow(size: 12, color: RefundTheme.reverse)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 19)
            .background(RefundTheme.ink)
            .opacity(configuration.isPressed ? 0.76 : (isEnabled ? 1 : 0.35))
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// The same block, outlined instead of filled.
struct RefundSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var tint: Color = RefundTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleOnly)
            .eyebrow(size: 11, color: tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay {
                Rectangle()
                    .stroke(tint.opacity(0.5), lineWidth: RefundTheme.hairline)
            }
            .background(configuration.isPressed ? tint.opacity(0.07) : .clear)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// An underlined word. For anything that would otherwise be a tinted link.
struct RefundTextButtonStyle: ButtonStyle {
    var tint: Color = RefundTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleOnly)
            .eyebrow(size: 11, color: tint)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(tint.opacity(0.4))
                    .frame(height: RefundTheme.hairline)
                    .offset(y: 3)
            }
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
