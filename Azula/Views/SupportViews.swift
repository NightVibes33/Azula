import SwiftUI

struct PatchLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var console: Console = .shared

    var body: some View {
        NavigationStack {
            ZStack {
                AzulaBackground()

                VStack(spacing: 14) {
                    AzulaSectionHeader(
                        title: "Technical Log",
                        subtitle: "Detailed patch activity and errors from the current session."
                    )

                    AzulaCard {
                        ConsoleView()
                            .frame(minHeight: 340)
                    }

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = console.logs
                                .map { "[\($0.type == .info ? "*" : "!")] \($0.message)" }
                                .joined(separator: "\n")
                        } label: {
                            Label("Copy Log", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 46)
                        }
                        .buttonStyle(AzulaSecondaryButtonStyle())
                        .disabled(console.logs.isEmpty)

                        Button(role: .destructive) {
                            console.clear()
                        } label: {
                            Label("Clear", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 46)
                        }
                        .buttonStyle(AzulaSecondaryButtonStyle())
                        .disabled(console.logs.isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("Patch Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AzulaTheme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct AboutHelpView: View {
    @Environment(\.dismiss) private var dismiss
    let replayOnboarding: () -> Void

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AzulaBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 10) {
                            AzulaFlameMark(size: 92)
                            Text("Azula")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AzulaTheme.warmWhite)
                            Text(versionText)
                                .font(.footnote)
                                .foregroundStyle(AzulaTheme.secondaryText)
                        }
                        .padding(.top, 10)

                        AzulaCard {
                            VStack(alignment: .leading, spacing: 14) {
                                helpRow(icon: "shippingbox.fill", title: "How Azula works", text: "Choose a decrypted IPA and compatible dylibs. Azula stages them in its sandbox, injects the libraries, and exports an unsigned IPA for your signer.")
                                Divider().overlay(Color.white.opacity(0.10))
                                helpRow(icon: "wrench.and.screwdriver.fill", title: "Compatibility", text: "ElleKit mode localizes common Substrate, libhooker, and ElleKit dependency paths beside the injected tweak.")
                                Divider().overlay(Color.white.opacity(0.10))
                                helpRow(icon: "signature", title: "Signing", text: "Your signer still needs to sign the app executable and every embedded library before installation.")
                            }
                        }

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                replayOnboarding()
                            }
                        } label: {
                            Label("View Onboarding Again", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                        }
                        .buttonStyle(AzulaSecondaryButtonStyle())
                    }
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AzulaTheme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func helpRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AzulaTheme.fireGradient)
                .frame(width: 38, height: 38)
                .background(AzulaTheme.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AzulaTheme.warmWhite)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(AzulaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PatchSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let outputURL: URL
    let dylibCount: Int
    let useElleKit: Bool
    let patchAnother: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AzulaBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 14)

                        ZStack {
                            Circle()
                                .fill(AzulaTheme.orange.opacity(0.12))
                                .frame(width: 142, height: 142)
                                .blur(radius: 12)

                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 94, weight: .bold))
                                .foregroundStyle(AzulaTheme.fireGradient)
                                .shadow(color: AzulaTheme.orange.opacity(0.40), radius: 18)
                        }

                        VStack(spacing: 8) {
                            Text("Patch Complete")
                                .font(.largeTitle.bold())
                                .foregroundStyle(AzulaTheme.warmWhite)

                            Text(outputURL.lastPathComponent)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AzulaTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .truncationMode(.middle)
                        }

                        AzulaCard {
                            VStack(spacing: 12) {
                                successRow(icon: "puzzlepiece.extension.fill", title: "Libraries", value: "\(dylibCount) injected")
                                successRow(icon: "wrench.and.screwdriver.fill", title: "ElleKit", value: useElleKit ? "Enabled" : "Disabled")
                                successRow(icon: "signature", title: "Output", value: "Unsigned")
                            }
                        }

                        ShareLink(item: outputURL) {
                            Label("Share to Signer", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 52)
                        }
                        .buttonStyle(AzulaPrimaryButtonStyle())

                        Button {
                            dismiss()
                            patchAnother()
                        } label: {
                            Text("Patch Another")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                        }
                        .buttonStyle(AzulaSecondaryButtonStyle())
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .navigationTitle("Output")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AzulaTheme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func successRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AzulaTheme.fireGradient)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(AzulaTheme.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(AzulaTheme.warmWhite)
        }
        .font(.subheadline)
    }
}
