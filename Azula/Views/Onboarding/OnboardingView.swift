import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var page = 0

    private let pageCount = 4

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 375
            let horizontalPadding = min(max(geometry.size.width * 0.065, 18), 30)

            ZStack {
                AzulaBackground()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 8)

                    TabView(selection: $page) {
                        welcomePage(compact: compact)
                            .tag(0)
                        workflowPage(compact: compact)
                            .tag(1)
                        compatibilityPage(compact: compact)
                            .tag(2)
                        readyPage(compact: compact)
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    footer(compact: compact)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                AzulaFlameMark(size: 30, glow: false)
                Text("AZULA")
                    .font(.caption.weight(.black))
                    .tracking(1.8)
                    .foregroundStyle(AzulaTheme.warmWhite)
            }

            Spacer()

            if page < pageCount - 1 {
                Button("Skip") {
                    onComplete()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AzulaTheme.secondaryText)
            }
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func welcomePage(compact: Bool) -> some View {
        onboardingContainer {
            Spacer(minLength: compact ? 10 : 26)

            ZStack {
                Circle()
                    .fill(AzulaTheme.orange.opacity(0.11))
                    .frame(width: compact ? 168 : 210, height: compact ? 168 : 210)
                    .blur(radius: 16)

                AzulaFlameMark(size: compact ? 126 : 154)
            }
            .padding(.bottom, compact ? 8 : 18)

            Text("Patch apps directly\non your iPhone")
                .font(compact ? .title.bold() : .largeTitle.bold())
                .foregroundStyle(AzulaTheme.warmWhite)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)

            Text("Import a decrypted IPA, choose one or more tweak dylibs, and Azula prepares a patched IPA for your normal sideload signer.")
                .font(.body)
                .foregroundStyle(AzulaTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            HStack(spacing: 12) {
                onboardingFlowNode(icon: "shippingbox.fill", label: "IPA")
                flowChevron
                onboardingFlowNode(icon: "flame.fill", label: "Azula", highlighted: true)
                flowChevron
                onboardingFlowNode(icon: "checkmark.seal.fill", label: "Patched")
            }
            .padding(.top, compact ? 16 : 24)

            Spacer(minLength: 10)
        }
    }

    @ViewBuilder
    private func workflowPage(compact: Bool) -> some View {
        onboardingContainer {
            Spacer(minLength: compact ? 6 : 18)

            onboardingTitle(
                eyebrow: "HOW IT WORKS",
                title: "Three steps. No clutter.",
                subtitle: "The workspace stays focused on the files and options that actually affect your patched IPA."
            )

            VStack(spacing: 12) {
                onboardingStep(number: "01", icon: "shippingbox.fill", title: "Choose IPA", detail: "Select a decrypted IPA from Files. Azula copies it into its sandbox before patching.")
                onboardingStep(number: "02", icon: "puzzlepiece.extension.fill", title: "Add dylibs", detail: "Choose one or multiple compatible tweak libraries without modifying your originals.")
                onboardingStep(number: "03", icon: "hammer.fill", title: "Patch & sign", detail: "Azula injects the libraries, exports an unsigned IPA, then hands it off to your signer.")
            }
            .padding(.top, compact ? 14 : 22)

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func compatibilityPage(compact: Bool) -> some View {
        onboardingContainer {
            Spacer(minLength: compact ? 4 : 16)

            onboardingTitle(
                eyebrow: "COMPATIBILITY",
                title: "Know what matters before you patch.",
                subtitle: "Azula is designed around modern arm64 sideloading on iOS 27."
            )

            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                compatibilityTile(icon: "iphone", title: "iOS 27", detail: "Modern arm64 iPhone workflow")
                compatibilityTile(icon: "wrench.and.screwdriver.fill", title: "ElleKit", detail: "Localizes common hook dependencies")
                compatibilityTile(icon: "signature", title: "Signing", detail: "Final IPA intentionally stays unsigned")
                compatibilityTile(icon: "lock.open.fill", title: "Decrypted IPA", detail: "Target executable must be patchable")
            }
            .padding(.top, compact ? 14 : 22)

            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private func readyPage(compact: Bool) -> some View {
        onboardingContainer {
            Spacer(minLength: compact ? 12 : 32)

            AzulaFlameMark(size: compact ? 92 : 116)
                .padding(.bottom, 8)

            onboardingTitle(
                eyebrow: "READY",
                title: "Your patch workspace is ready.",
                subtitle: "The interface adapts to the live window size, rotation, Display Zoom, and Dynamic Type."
            )

            AzulaCard {
                VStack(alignment: .leading, spacing: 13) {
                    checklistRow("iOS 27 real-device build")
                    checklistRow("Adaptive iPhone layout")
                    checklistRow("Multiple dylib import")
                    checklistRow("ElleKit compatibility")
                    checklistRow("Files sandbox integration")
                }
            }
            .padding(.top, compact ? 14 : 22)

            Spacer(minLength: 10)
        }
    }

    private func onboardingContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func onboardingTitle(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(AzulaTheme.gold)

            Text(title)
                .font(.title.bold())
                .foregroundStyle(AzulaTheme.warmWhite)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(AzulaTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func onboardingFlowNode(icon: String, label: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(highlighted ? AnyShapeStyle(AzulaTheme.fireGradient) : AnyShapeStyle(AzulaTheme.warmWhite))
                .frame(width: 46, height: 46)
                .background(AzulaTheme.gunmetal.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(highlighted ? AzulaTheme.orange.opacity(0.70) : AzulaTheme.gunmetalLight.opacity(0.44), lineWidth: 1)
                }

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AzulaTheme.secondaryText)
        }
    }

    private var flowChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(AzulaTheme.tertiaryText)
            .offset(y: -10)
    }

    private func onboardingStep(number: String, icon: String, title: String, detail: String) -> some View {
        AzulaCard {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 6) {
                    Text(number)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(AzulaTheme.gold)
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AzulaTheme.fireGradient)
                }
                .frame(width: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AzulaTheme.warmWhite)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(AzulaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func compatibilityTile(icon: String, title: String, detail: String) -> some View {
        AzulaCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AzulaTheme.fireGradient)
                    .frame(width: 42, height: 42)
                    .background(AzulaTheme.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(AzulaTheme.warmWhite)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AzulaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func checklistRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AzulaTheme.fireGradient)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AzulaTheme.warmWhite)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func footer(compact: Bool) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? AnyShapeStyle(AzulaTheme.fireGradient) : AnyShapeStyle(AzulaTheme.gunmetalLight.opacity(0.35)))
                        .frame(width: index == page ? 24 : 7, height: 7)
                        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: page)
                }
            }

            Button {
                if page == pageCount - 1 {
                    onComplete()
                } else {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
                        page += 1
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    Text(page == pageCount - 1 ? "Start Patching" : "Continue")
                        .font(.headline)
                    Image(systemName: page == pageCount - 1 ? "flame.fill" : "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: compact ? 48 : 52)
            }
            .buttonStyle(AzulaPrimaryButtonStyle())
        }
    }
}
