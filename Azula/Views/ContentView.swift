//
//  ContentView.swift
//  Azula
//
//  Created by Lilliana on 15/05/2023.
//

import SwiftUI

private struct AdaptiveLayout {
    let size: CGSize
    let accessibilityText: Bool

    var isLandscape: Bool { size.width > size.height }
    var usesTwoColumns: Bool { isLandscape && size.width >= 640 && !accessibilityText }

    var horizontalPadding: CGFloat {
        min(max(size.width * 0.045, 14), 28)
    }

    var sectionSpacing: CGFloat {
        accessibilityText ? 20 : min(max(size.height * 0.018, 14), 20)
    }

    var cardSpacing: CGFloat {
        accessibilityText ? 14 : min(max(size.width * 0.03, 10), 16)
    }

    var heroIconSize: CGFloat {
        min(max(min(size.width, size.height) * 0.105, 34), 52)
    }

    var heroTopPadding: CGFloat {
        isLandscape ? 4 : min(max(size.height * 0.012, 6), 14)
    }

    var controlMinHeight: CGFloat {
        accessibilityText ? 54 : (size.width < 375 ? 44 : 48)
    }

    var consoleHeight: CGFloat {
        let fraction = isLandscape ? 0.42 : 0.27
        let upperBound: CGFloat = isLandscape ? 280 : 300
        return min(max(size.height * fraction, 160), upperBound)
    }

    var maxContentWidth: CGFloat {
        usesTwoColumns ? 960 : 640
    }
}

struct ContentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var useElleKit = true
    @State private var isImporting = false
    @State private var isPatching = false
    @State private var ipaURL: URL?
    @State private var dylibURLs: [URL] = []
    @State private var outputURL: URL?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let layout = AdaptiveLayout(
                    size: geometry.size,
                    accessibilityText: dynamicTypeSize.isAccessibilitySize
                )

                ScrollView {
                    VStack(spacing: layout.sectionSpacing) {
                        header(layout: layout)

                        if layout.usesTwoColumns {
                            HStack(alignment: .top, spacing: layout.cardSpacing) {
                                inputsCard(layout: layout)
                                    .frame(maxWidth: .infinity, alignment: .top)
                                compatibilityCard
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            inputsCard(layout: layout)
                            compatibilityCard
                        }

                        patchButton(layout: layout)

                        if let outputURL {
                            outputCard(outputURL: outputURL, layout: layout)
                        }

                        GroupBox {
                            ConsoleView()
                                .frame(height: layout.consoleHeight)
                        } label: {
                            Label("Patch Log", systemImage: "terminal")
                        }
                    }
                    .frame(maxWidth: layout.maxContentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, layout.heroTopPadding)
                    .padding(.bottom, max(layout.horizontalPadding, 18))
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Azula")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isImporting) {
                FilePickerView(ipaURL: $ipaURL, dylibURLs: $dylibURLs, isShowing: $isImporting)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func header(layout: AdaptiveLayout) -> some View {
        VStack(spacing: layout.isLandscape ? 5 : 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: layout.heroIconSize, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Azula")
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text("Dylib injection for sideloaded iOS 27 apps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func inputsCard(layout: AdaptiveLayout) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                inputRow(
                    title: "IPA",
                    value: ipaURL?.lastPathComponent ?? "Not selected",
                    icon: "shippingbox"
                )

                Divider()

                inputRow(
                    title: "Dylibs",
                    value: dylibURLs.isEmpty ? "Not selected" : "\(dylibURLs.count) selected",
                    icon: "puzzlepiece.extension"
                )

                Button {
                    isImporting = true
                } label: {
                    Label(ipaURL == nil ? "Select Files" : "Change Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: layout.controlMinHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        } label: {
            Label("Inputs", systemImage: "square.and.arrow.down")
        }
    }

    private var compatibilityCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("ElleKit compatibility", isOn: $useElleKit)
                    .fixedSize(horizontal: false, vertical: true)

                Text("For jailbreak-style tweaks, Azula stages ElleKit beside the tweak and rewrites common Substrate/libhooker paths to the local copy. Your original dylib files are not modified.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } label: {
            Label("Compatibility", systemImage: "wrench.and.screwdriver")
        }
    }

    @ViewBuilder
    private func patchButton(layout: AdaptiveLayout) -> some View {
        Button {
            Task { await patch() }
        } label: {
            HStack(spacing: 10) {
                if isPatching {
                    ProgressView()
                } else {
                    Image(systemName: "hammer.fill")
                }

                Text(isPatching ? "Building Patched IPA…" : "Build Patched IPA")
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: layout.controlMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(ipaURL == nil || dylibURLs.isEmpty || isPatching)
        .accessibilityHint("Creates a new unsigned IPA containing the selected dylibs")
    }

    @ViewBuilder
    private func outputCard(outputURL: URL, layout: AdaptiveLayout) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(outputURL.lastPathComponent)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundStyle(.green)

                Text("This output is intentionally unsigned. Open it in your normal iOS sideload signer, sign every embedded executable/dylib, then install it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShareLink(item: outputURL) {
                    Label("Share Patched IPA", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: layout.controlMinHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }
        } label: {
            Label("Output", systemImage: "shippingbox.fill")
        }
    }

    @ViewBuilder
    private func inputRow(title: String, value: String, icon: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.headline)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func patch() async {
        guard let selectedIPA = ipaURL, !dylibURLs.isEmpty else { return }

        let selectedDylibs = dylibURLs
        let shouldUseElleKit = useElleKit
        let bundledElleKit = shouldUseElleKit
            ? Bundle.main.url(forResource: "libellekit", withExtension: "dylib")
            : nil

        isPatching = true
        outputURL = nil
        Console.shared.log("Starting iOS 27 sideload patch…", type: .info)

        let result = await Task.detached(priority: .userInitiated) { () -> URL? in
            let helper = IPAHelper(url: selectedIPA)

            guard let binaryURL = helper.getBinaryURL() else { return nil }

            var stagedDylibs: [URL] = []
            for dylibURL in selectedDylibs {
                guard let stagedURL = helper.addDylib(dylibURL) else {
                    Console.shared.log("Couldn't stage \(dylibURL.lastPathComponent)", type: .error)
                    return nil
                }
                stagedDylibs.append(stagedURL)
            }

            if shouldUseElleKit {
                guard let bundledElleKit,
                      helper.addDylib(bundledElleKit, named: "AzulaElleKit.dylib") != nil
                else {
                    Console.shared.log("Bundled ElleKit compatibility library is missing", type: .error)
                    return nil
                }

                let legacyHookPaths = [
                    "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
                    "/var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
                    "/usr/lib/libsubstrate.dylib",
                    "/usr/lib/libhooker.dylib",
                    "/usr/lib/libellekit.dylib",
                    "/var/jb/usr/lib/libellekit.dylib",
                ]

                for stagedURL in stagedDylibs {
                    let tweakBinary = Azula(injecting: [], removing: [], from: stagedURL)
                    guard tweakBinary.replaceLoadPaths(
                        legacyHookPaths,
                        with: "@loader_path/AzulaElleKit.dylib"
                    ) else {
                        Console.shared.log("Couldn't localize hook dependencies in \(stagedURL.lastPathComponent)", type: .error)
                        return nil
                    }
                }
            }

            // Construct this last because Azula's parser state describes one
            // target binary at a time.
            let injectionPaths = stagedDylibs.map {
                "@executable_path/Frameworks/\($0.lastPathComponent)"
            }
            let appBinary = Azula(injecting: injectionPaths, removing: [], from: binaryURL)

            guard appBinary.inject() else { return nil }
            guard let patchedIPA = helper.repackIPA() else { return nil }

            Console.shared.log("Patched IPA is ready for your sideload signer", type: .info)
            return patchedIPA
        }.value

        outputURL = result
        isPatching = false

        if result == nil {
            Console.shared.log("Patch failed. Review the log above for the exact cause.", type: .error)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
