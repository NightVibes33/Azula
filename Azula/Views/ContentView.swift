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
        min(max(min(size.width, size.height) * 0.105, 40), 62)
    }

    var controlMinHeight: CGFloat {
        accessibilityText ? 56 : (size.width < 375 ? 48 : 52)
    }

    var maxContentWidth: CGFloat {
        usesTwoColumns ? 980 : 660
    }
}

private enum PatchPhase: Equatable {
    case idle
    case preparing
    case copying
    case resolving
    case injecting
    case repacking
    case complete
    case failed

    var title: String {
        switch self {
        case .idle: return "Ready to configure patch"
        case .preparing: return "Preparing IPA"
        case .copying: return "Copying libraries"
        case .resolving: return "Resolving dependencies"
        case .injecting: return "Injecting load commands"
        case .repacking: return "Repacking IPA"
        case .complete: return "Patch complete"
        case .failed: return "Patch failed"
        }
    }

    var detail: String {
        switch self {
        case .idle: return "Choose a target IPA and at least one dylib to begin."
        case .preparing: return "Opening the target app and preparing its executable."
        case .copying: return "Staging selected libraries inside the app Frameworks directory."
        case .resolving: return "Localizing supported hook dependencies for sideloading."
        case .injecting: return "Adding load commands to the target executable."
        case .repacking: return "Creating the final unsigned IPA for your signer."
        case .complete: return "Your patched IPA is ready to share to a signer."
        case .failed: return "Open the technical log for the exact failure reported by the patch engine."
        }
    }

    var icon: String {
        switch self {
        case .idle: return "circle.dotted"
        case .preparing: return "shippingbox"
        case .copying: return "doc.on.doc"
        case .resolving: return "link"
        case .injecting: return "puzzlepiece.extension.fill"
        case .repacking: return "archivebox.fill"
        case .complete: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    var step: Int {
        switch self {
        case .idle: return 0
        case .preparing: return 1
        case .copying: return 2
        case .resolving: return 3
        case .injecting: return 4
        case .repacking: return 5
        case .complete: return 6
        case .failed: return 0
        }
    }
}

struct ContentView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let replayOnboarding: () -> Void

    @State private var useElleKit = true
    @State private var isImporting = false
    @State private var isPatching = false
    @State private var showingLog = false
    @State private var showingHelp = false
    @State private var showingSuccess = false
    @State private var ipaURL: URL?
    @State private var dylibURLs: [URL] = []
    @State private var outputURL: URL?
    @State private var patchPhase: PatchPhase = .idle

    init(replayOnboarding: @escaping () -> Void = {}) {
        self.replayOnboarding = replayOnboarding
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AzulaBackground()

                GeometryReader { geometry in
                    let layout = AdaptiveLayout(
                        size: geometry.size,
                        accessibilityText: dynamicTypeSize.isAccessibilitySize
                    )

                    ScrollView {
                        VStack(spacing: layout.sectionSpacing) {
                            header(layout: layout)
                            stepRail

                            AzulaSectionHeader(
                                title: "Patch Workspace",
                                subtitle: "Configure the target and injected libraries."
                            )

                            if layout.usesTwoColumns {
                                HStack(alignment: .top, spacing: layout.cardSpacing) {
                                    targetCard(layout: layout)
                                    dylibCard(layout: layout)
                                }
                            } else {
                                targetCard(layout: layout)
                                dylibCard(layout: layout)
                            }

                            AzulaSectionHeader(title: "Compatibility")
                            compatibilityCard

                            AzulaSectionHeader(title: "Activity")
                            activityCard
                        }
                        .frame(maxWidth: layout.maxContentWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, layout.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 34)
                    }
                    .scrollIndicators(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        buildBar(layout: layout)
                    }
                }
            }
            .navigationTitle("Azula")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AzulaTheme.gold)
                    }
                    .accessibilityLabel("About Azula")
                }
            }
            .sheet(isPresented: $isImporting) {
                FilePickerView(ipaURL: $ipaURL, dylibURLs: $dylibURLs, isShowing: $isImporting)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingLog) {
                PatchLogSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingHelp) {
                AboutHelpView(replayOnboarding: replayOnboarding)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingSuccess) {
                if let outputURL {
                    PatchSuccessView(
                        outputURL: outputURL,
                        dylibCount: dylibURLs.count,
                        useElleKit: useElleKit,
                        patchAnother: resetWorkspace
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func header(layout: AdaptiveLayout) -> some View {
        HStack(spacing: 14) {
            AzulaFlameMark(size: layout.heroIconSize)

            VStack(alignment: .leading, spacing: 3) {
                Text("AZULA")
                    .font(.title2.weight(.black))
                    .tracking(2.2)
                    .foregroundStyle(AzulaTheme.warmWhite)

                Text("iOS App Injection")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AzulaTheme.secondaryText)
            }

            Spacer(minLength: 0)

            AzulaStatusBadge(
                text: "iOS 27",
                systemImage: "iphone",
                tint: AzulaTheme.gold
            )
        }
        .padding(.vertical, layout.isLandscape ? 4 : 10)
        .accessibilityElement(children: .combine)
    }

    private var stepRail: some View {
        HStack(spacing: 8) {
            workspaceStep(number: 1, title: "IPA", complete: ipaURL != nil, active: ipaURL == nil)
            stepConnector(complete: ipaURL != nil)
            workspaceStep(number: 2, title: "Dylibs", complete: !dylibURLs.isEmpty, active: ipaURL != nil && dylibURLs.isEmpty)
            stepConnector(complete: ipaURL != nil && !dylibURLs.isEmpty)
            workspaceStep(number: 3, title: "Build", complete: patchPhase == .complete, active: ipaURL != nil && !dylibURLs.isEmpty)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func workspaceStep(number: Int, title: String, complete: Bool, active: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(complete || active ? AzulaTheme.orange.opacity(0.14) : AzulaTheme.gunmetal.opacity(0.55))
                    .overlay {
                        Circle()
                            .stroke(complete || active ? AzulaTheme.orange.opacity(0.70) : AzulaTheme.gunmetalLight.opacity(0.35), lineWidth: 1)
                    }

                if complete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(AzulaTheme.gold)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(active ? AzulaTheme.gold : AzulaTheme.tertiaryText)
                }
            }
            .frame(width: 30, height: 30)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(active || complete ? AzulaTheme.warmWhite : AzulaTheme.tertiaryText)
        }
        .frame(minWidth: 58)
    }

    private func stepConnector(complete: Bool) -> some View {
        Capsule()
            .fill(complete ? AnyShapeStyle(AzulaTheme.fireGradient) : AnyShapeStyle(AzulaTheme.gunmetalLight.opacity(0.28)))
            .frame(maxWidth: .infinity)
            .frame(height: 2)
            .offset(y: -9)
    }

    @ViewBuilder
    private func targetCard(layout: AdaptiveLayout) -> some View {
        AzulaCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    fileIcon(systemImage: "shippingbox.fill")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Application")
                            .font(.headline)
                            .foregroundStyle(AzulaTheme.warmWhite)

                        if let ipaURL {
                            Text(ipaURL.lastPathComponent)
                                .font(.footnote)
                                .foregroundStyle(AzulaTheme.secondaryText)
                                .lineLimit(2)
                                .truncationMode(.middle)

                            AzulaStatusBadge(text: "IPA • Ready", systemImage: "checkmark.circle.fill", tint: AzulaTheme.gold)
                                .padding(.top, 4)
                        } else {
                            Text("No IPA selected")
                                .font(.footnote)
                                .foregroundStyle(AzulaTheme.secondaryText)
                            Text("Choose a decrypted IPA from Files.")
                                .font(.caption)
                                .foregroundStyle(AzulaTheme.tertiaryText)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Button {
                    isImporting = true
                } label: {
                    Label(ipaURL == nil ? "Choose IPA" : "Replace IPA", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: layout.controlMinHeight)
                }
                .buttonStyle(AzulaSecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func dylibCard(layout: AdaptiveLayout) -> some View {
        AzulaCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    fileIcon(systemImage: "puzzlepiece.extension.fill")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Injected Libraries")
                            .font(.headline)
                            .foregroundStyle(AzulaTheme.warmWhite)

                        if dylibURLs.isEmpty {
                            Text("No dylibs selected")
                                .font(.footnote)
                                .foregroundStyle(AzulaTheme.secondaryText)
                            Text("Choose one or multiple compatible libraries.")
                                .font(.caption)
                                .foregroundStyle(AzulaTheme.tertiaryText)
                        } else {
                            Text("\(dylibURLs.count) selected")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AzulaTheme.gold)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if !dylibURLs.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(dylibURLs.prefix(3)), id: \.self) { url in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.badge.gearshape")
                                    .font(.caption)
                                    .foregroundStyle(AzulaTheme.orange)
                                Text(url.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(AzulaTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        if dylibURLs.count > 3 {
                            Text("+ \(dylibURLs.count - 3) more")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AzulaTheme.tertiaryText)
                        }
                    }
                    .padding(11)
                    .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    isImporting = true
                } label: {
                    Label(dylibURLs.isEmpty ? "Choose Dylibs" : "Change Dylibs", systemImage: "folder.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: layout.controlMinHeight)
                }
                .buttonStyle(AzulaSecondaryButtonStyle())
            }
        }
    }

    private var compatibilityCard: some View {
        AzulaCard {
            HStack(alignment: .top, spacing: 13) {
                fileIcon(systemImage: "wrench.and.screwdriver.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Text("ElleKit compatibility")
                        .font(.headline)
                        .foregroundStyle(AzulaTheme.warmWhite)

                    Text("Localize common Substrate, libhooker, and ElleKit dependencies beside injected tweaks. Your original dylib files stay untouched.")
                        .font(.footnote)
                        .foregroundStyle(AzulaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $useElleKit)
                    .labelsHidden()
                    .tint(AzulaTheme.orange)
            }
        }
    }

    private var activityCard: some View {
        Button {
            showingLog = true
        } label: {
            AzulaCard {
                HStack(spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill((patchPhase == .failed ? Color.red : AzulaTheme.orange).opacity(0.10))

                        if isPatching {
                            ProgressView()
                                .tint(AzulaTheme.gold)
                        } else {
                            Image(systemName: patchPhase.icon)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(patchPhase == .failed ? AnyShapeStyle(Color.red) : AnyShapeStyle(AzulaTheme.fireGradient))
                        }
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(patchPhase.title)
                            .font(.headline)
                            .foregroundStyle(AzulaTheme.warmWhite)

                        Text(patchPhase.detail)
                            .font(.caption)
                            .foregroundStyle(AzulaTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AzulaTheme.tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the full technical patch log")
    }

    private func buildBar(layout: AdaptiveLayout) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, AzulaTheme.orange.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Button {
                Task { await patch() }
            } label: {
                HStack(spacing: 10) {
                    if isPatching {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "flame.fill")
                    }

                    Text(isPatching ? patchPhase.title : "Build Patched IPA")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: layout.controlMinHeight)
            }
            .buttonStyle(AzulaPrimaryButtonStyle())
            .disabled(ipaURL == nil || dylibURLs.isEmpty || isPatching)
            .opacity(ipaURL == nil || dylibURLs.isEmpty ? 0.42 : 1)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.72))
    }

    private func fileIcon(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AzulaTheme.fireGradient)
            .frame(width: 46, height: 46)
            .background(AzulaTheme.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AzulaTheme.orange.opacity(0.20), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func setPhase(_ phase: PatchPhase) async {
        await MainActor.run {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                patchPhase = phase
            }
        }
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
        patchPhase = .preparing
        Console.shared.log("Starting iOS 27 sideload patch…", type: .info)

        let result = await Task.detached(priority: .userInitiated) { () -> URL? in
            let helper = IPAHelper(url: selectedIPA)

            guard let binaryURL = helper.getBinaryURL() else { return nil }

            await setPhase(.copying)
            var stagedDylibs: [URL] = []
            for dylibURL in selectedDylibs {
                guard let stagedURL = helper.addDylib(dylibURL) else {
                    Console.shared.log("Couldn't stage \(dylibURL.lastPathComponent)", type: .error)
                    return nil
                }
                stagedDylibs.append(stagedURL)
            }

            if shouldUseElleKit {
                await setPhase(.resolving)

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

            await setPhase(.injecting)

            // Construct this last because Azula's parser state describes one
            // target binary at a time.
            let injectionPaths = stagedDylibs.map {
                "@executable_path/Frameworks/\($0.lastPathComponent)"
            }
            let appBinary = Azula(injecting: injectionPaths, removing: [], from: binaryURL)

            guard appBinary.inject() else { return nil }

            await setPhase(.repacking)
            guard let patchedIPA = helper.repackIPA() else { return nil }

            Console.shared.log("Patched IPA is ready for your sideload signer", type: .info)
            return patchedIPA
        }.value

        outputURL = result
        isPatching = false

        if result == nil {
            patchPhase = .failed
            Console.shared.log("Patch failed. Review the log for the exact cause.", type: .error)
        } else {
            patchPhase = .complete
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                showingSuccess = true
            }
        }
    }

    private func resetWorkspace() {
        ipaURL = nil
        dylibURLs = []
        outputURL = nil
        patchPhase = .idle
        Console.shared.clear()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
