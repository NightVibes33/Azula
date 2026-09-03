import SwiftUI

enum AzulaTheme {
    static let backgroundTop = Color(red: 0.015, green: 0.020, blue: 0.035)
    static let backgroundBottom = Color(red: 0.002, green: 0.004, blue: 0.009)
    static let gunmetal = Color(red: 0.16, green: 0.18, blue: 0.24)
    static let gunmetalLight = Color(red: 0.34, green: 0.37, blue: 0.47)
    static let ember = Color(red: 1.00, green: 0.20, blue: 0.02)
    static let orange = Color(red: 1.00, green: 0.39, blue: 0.02)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.18)
    static let warmWhite = Color(red: 1.00, green: 0.96, blue: 0.89)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.38)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let fireGradient = LinearGradient(
        colors: [gold, orange, ember],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let fireGradientVertical = LinearGradient(
        colors: [gold, orange, ember],
        startPoint: .top,
        endPoint: .bottom
    )

    static let metalGradient = LinearGradient(
        colors: [gunmetalLight, gunmetal, Color.black.opacity(0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AzulaBackground: View {
    var body: some View {
        ZStack {
            AzulaTheme.backgroundGradient

            RadialGradient(
                colors: [AzulaTheme.orange.opacity(0.18), .clear],
                center: UnitPoint(x: 0.82, y: 0.04),
                startRadius: 8,
                endRadius: 360
            )

            RadialGradient(
                colors: [AzulaTheme.gunmetalLight.opacity(0.10), .clear],
                center: UnitPoint(x: 0.12, y: 0.72),
                startRadius: 10,
                endRadius: 430
            )
        }
        .ignoresSafeArea()
    }
}

struct AzulaFlameMark: View {
    var size: CGFloat = 54
    var glow: Bool = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(AzulaTheme.metalGradient, lineWidth: max(2, size * 0.055))
                .overlay {
                    Circle()
                        .trim(from: 0.03, to: 0.86)
                        .stroke(AzulaTheme.fireGradient, style: StrokeStyle(lineWidth: max(1.5, size * 0.026), lineCap: .round))
                        .rotationEffect(.degrees(-84))
                }

            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.56, weight: .bold))
                .foregroundStyle(AzulaTheme.fireGradientVertical)
                .shadow(color: glow ? AzulaTheme.orange.opacity(0.58) : .clear, radius: size * 0.12)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct AzulaCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AzulaTheme.gunmetalLight.opacity(0.62),
                                AzulaTheme.orange.opacity(0.22),
                                Color.white.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
    }
}

struct AzulaSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.25)
                .foregroundStyle(AzulaTheme.gold)

            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AzulaTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AzulaStatusBadge: View {
    let text: String
    let systemImage: String
    var tint: Color = AzulaTheme.orange

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.28), lineWidth: 1)
            }
    }
}

struct AzulaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black.opacity(0.88))
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AzulaTheme.fireGradient)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: AzulaTheme.orange.opacity(configuration.isPressed ? 0.14 : 0.34), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct AzulaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AzulaTheme.warmWhite)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AzulaTheme.gunmetal.opacity(configuration.isPressed ? 0.70 : 0.48))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AzulaTheme.gunmetalLight.opacity(0.54), lineWidth: 1)
            }
    }
}
