import SwiftUI

enum RefundTheme {
    static let violet = Color(red: 0.43, green: 0.28, blue: 0.95)
    static let blue = Color(red: 0.12, green: 0.56, blue: 0.98)
    static let mint = Color(red: 0.10, green: 0.76, blue: 0.62)
    static let coral = Color(red: 1.00, green: 0.39, blue: 0.45)
    static let mango = Color(red: 1.00, green: 0.68, blue: 0.20)
    static let pink = Color(red: 0.91, green: 0.32, blue: 0.72)

    static let palette = [violet, blue, mint, coral, mango, pink]

    static func color(for text: String) -> Color {
        let value = text.unicodeScalars.reduce(0) {
            (($0 &* 31) &+ Int($1.value)) & 0x7fff_ffff
        }
        return palette[value % palette.count]
    }

    static func gradient(for text: String) -> LinearGradient {
        let firstIndex = paletteIndex(for: text)
        let secondIndex = (firstIndex + 2) % palette.count
        return LinearGradient(
            colors: [palette[firstIndex], palette[secondIndex]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func paletteIndex(for text: String) -> Int {
        let value = text.unicodeScalars.reduce(0) {
            (($0 &* 31) &+ Int($1.value)) & 0x7fff_ffff
        }
        return value % palette.count
    }
}

struct RefundBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            LinearGradient(
                colors: [
                    RefundTheme.violet.opacity(colorScheme == .dark ? 0.24 : 0.14),
                    RefundTheme.blue.opacity(colorScheme == .dark ? 0.13 : 0.08),
                    RefundTheme.pink.opacity(colorScheme == .dark ? 0.16 : 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(RefundTheme.mango.opacity(colorScheme == .dark ? 0.16 : 0.19))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: 150, y: -310)

            Circle()
                .fill(RefundTheme.mint.opacity(colorScheme == .dark ? 0.13 : 0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 82)
                .offset(x: -170, y: 360)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct MerchantMark: View {
    let name: String
    var size: CGFloat = 48

    var body: some View {
        Text(monogram)
            .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RefundTheme.gradient(for: name))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .stroke(.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(
                color: RefundTheme.color(for: name).opacity(0.24),
                radius: 9,
                y: 5
            )
            .accessibilityHidden(true)
    }

    private var monogram: String {
        let words = name
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
        let letters = words.compactMap(\.first)
        return letters.isEmpty ? "$" : String(letters).uppercased()
    }
}

private struct RefundGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(tint.opacity(colorScheme == .dark ? 0.09 : 0.055))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(
                                .white.opacity(colorScheme == .dark ? 0.14 : 0.62),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(
                color: tint.opacity(colorScheme == .dark ? 0.10 : 0.12),
                radius: 22,
                y: 12
            )
    }
}

extension View {
    func refundGlassCard(
        tint: Color = RefundTheme.violet,
        padding: CGFloat = 18
    ) -> some View {
        modifier(RefundGlassCardModifier(tint: tint, padding: padding))
    }
}

struct RefundSectionHeading: View {
    let title: String
    var subtitle: String?
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(RefundTheme.violet)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

struct RefundPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [RefundTheme.violet, RefundTheme.blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(
                color: RefundTheme.violet.opacity(configuration.isPressed ? 0.14 : 0.28),
                radius: configuration.isPressed ? 5 : 12,
                y: configuration.isPressed ? 2 : 7
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
