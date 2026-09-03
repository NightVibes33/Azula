//
//  FilePickerView.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: View {
    @Binding var ipaURL: URL?
    @Binding var dylibURLs: [URL]
    @Binding var isShowing: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var ipaImporting = false
    @State private var dylibImporting = false

    private let console: Console = .shared
    private let fileManager = FileManager.default

    var body: some View {
        NavigationStack {
            ZStack {
                AzulaBackground()

                GeometryReader { geometry in
                    let compact = geometry.size.width < 375
                    let horizontalPadding = min(max(geometry.size.width * 0.055, 16), 26)

                    ScrollView {
                        VStack(spacing: compact ? 14 : 18) {
                            VStack(spacing: 8) {
                                AzulaFlameMark(size: compact ? 54 : 64)
                                Text("Patch Files")
                                    .font(.title.bold())
                                    .foregroundStyle(AzulaTheme.warmWhite)
                                Text("Azula copies imports into its own sandbox before patching. Your originals in Files stay untouched.")
                                    .font(.footnote)
                                    .foregroundStyle(AzulaTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 10)

                            AzulaSectionHeader(title: "Target", subtitle: "Choose one decrypted IPA.")

                            AzulaCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    selectionRow(
                                        title: ipaURL == nil ? "Choose IPA" : "Selected IPA",
                                        value: ipaURL?.lastPathComponent,
                                        icon: "shippingbox.fill",
                                        ready: ipaURL != nil
                                    )

                                    Button {
                                        ipaImporting = true
                                    } label: {
                                        Label(ipaURL == nil ? "Browse Files" : "Replace IPA", systemImage: "folder")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 48)
                                    }
                                    .buttonStyle(AzulaSecondaryButtonStyle())
                                    // Files providers frequently advertise .ipa as generic data/archive.
                                    // Accept data here, then enforce the actual extension after selection.
                                    .fileImporter(
                                        isPresented: $ipaImporting,
                                        allowedContentTypes: [.data]
                                    ) { result in
                                        switch result {
                                        case .success(let sourceURL):
                                            guard validate(sourceURL, expectedExtension: "ipa") else { return }
                                            ipaURL = importFile(sourceURL, folder: "IPA")
                                        case .failure(let error):
                                            console.log("IPA import failed: \(error.localizedDescription)", type: .error)
                                        }
                                    }
                                }
                            }

                            AzulaSectionHeader(title: "Injected Libraries", subtitle: "Choose one or multiple dylibs.")

                            AzulaCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    selectionRow(
                                        title: dylibURLs.isEmpty ? "Choose Dylibs" : "Dylibs Ready",
                                        value: dylibURLs.isEmpty ? nil : "\(dylibURLs.count) selected",
                                        icon: "puzzlepiece.extension.fill",
                                        ready: !dylibURLs.isEmpty
                                    )

                                    if !dylibURLs.isEmpty {
                                        VStack(spacing: 8) {
                                            ForEach(dylibURLs, id: \.self) { url in
                                                dylibRow(url)
                                            }
                                        }
                                    }

                                    Button {
                                        dylibImporting = true
                                    } label: {
                                        Label(dylibURLs.isEmpty ? "Browse Dylibs" : "Change Dylibs", systemImage: "folder.badge.plus")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .frame(minHeight: 48)
                                    }
                                    .buttonStyle(AzulaSecondaryButtonStyle())
                                    // public.dylib is inconsistently reported by Files providers.
                                    // Use public.data so the row is selectable, then hard-check .dylib below.
                                    .fileImporter(
                                        isPresented: $dylibImporting,
                                        allowedContentTypes: [.data],
                                        allowsMultipleSelection: true
                                    ) { result in
                                        switch result {
                                        case .success(let sourceURLs):
                                            let accepted = sourceURLs.filter {
                                                $0.pathExtension.lowercased() == "dylib"
                                            }
                                            let rejected = sourceURLs.filter {
                                                $0.pathExtension.lowercased() != "dylib"
                                            }

                                            for url in rejected {
                                                console.log("Skipped non-dylib file: \(url.lastPathComponent)", type: .warn)
                                            }

                                            guard !accepted.isEmpty else {
                                                console.log("No .dylib files were selected", type: .error)
                                                return
                                            }

                                            dylibURLs = importDylibs(accepted)
                                        case .failure(let error):
                                            console.log("Dylib import failed: \(error.localizedDescription)", type: .error)
                                        }
                                    }
                                }
                            }

                            AzulaCard {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.title3)
                                        .foregroundStyle(AzulaTheme.fireGradient)
                                        .accessibilityHidden(true)

                                    Text("Files can report IPA and dylib files with generic content types. Azula allows generic file data in the picker, then strictly validates .ipa and .dylib extensions before importing.")
                                        .font(.footnote)
                                        .foregroundStyle(AzulaTheme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: 680)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, 30)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowing = false }
                        .foregroundStyle(AzulaTheme.secondaryText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowing = false }
                        .fontWeight(.semibold)
                        .foregroundStyle(AzulaTheme.gold)
                        .disabled(ipaURL == nil || dylibURLs.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func selectionRow(title: String, value: String?, icon: String, ready: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AzulaTheme.fireGradient)
                .frame(width: 46, height: 46)
                .background(AzulaTheme.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AzulaTheme.warmWhite)

                if let value {
                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(AzulaTheme.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                        .truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if ready {
                    AzulaStatusBadge(text: "Ready", systemImage: "checkmark.circle.fill", tint: AzulaTheme.gold)
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func dylibRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.badge.gearshape")
                .foregroundStyle(AzulaTheme.orange)
                .frame(width: 24)

            Text(url.lastPathComponent)
                .font(.footnote)
                .foregroundStyle(AzulaTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            Button(role: .destructive) {
                dylibURLs.removeAll { $0 == url }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.red.opacity(0.85))
                    .font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(url.lastPathComponent)")
        }
        .padding(10)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AzulaTheme.gunmetalLight.opacity(0.26), lineWidth: 1)
        }
    }

    private func validate(_ sourceURL: URL, expectedExtension: String) -> Bool {
        let actual = sourceURL.pathExtension.lowercased()
        guard actual == expectedExtension.lowercased() else {
            console.log(
                "Expected .\(expectedExtension), got \(sourceURL.lastPathComponent)",
                type: .error
            )
            return false
        }
        return true
    }

    private func importDylibs(_ sourceURLs: [URL]) -> [URL] {
        let root = importRoot.appendingPathComponent("Dylibs", isDirectory: true)
        do {
            if fileManager.fileExists(atPath: root.path) {
                try fileManager.removeItem(at: root)
            }
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            console.log("Couldn't prepare dylib imports: \(error.localizedDescription)", type: .error)
            return []
        }

        var imported: [URL] = []
        var names = Set<String>()

        for sourceURL in sourceURLs {
            let name = sourceURL.lastPathComponent
            guard names.insert(name).inserted else {
                console.log("Duplicate dylib filename skipped: \(name)", type: .warn)
                continue
            }
            if let destination = copySecurityScopedFile(sourceURL, to: root.appendingPathComponent(name)) {
                imported.append(destination)
            }
        }

        return imported
    }

    private func importFile(_ sourceURL: URL, folder: String) -> URL? {
        let root = importRoot.appendingPathComponent(folder, isDirectory: true)
        do {
            if fileManager.fileExists(atPath: root.path) {
                try fileManager.removeItem(at: root)
            }
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            console.log("Couldn't prepare import folder: \(error.localizedDescription)", type: .error)
            return nil
        }

        return copySecurityScopedFile(sourceURL, to: root.appendingPathComponent(sourceURL.lastPathComponent))
    }

    private func copySecurityScopedFile(_ sourceURL: URL, to destinationURL: URL) -> URL? {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if scoped { sourceURL.stopAccessingSecurityScopedResource() }
        }

        var coordinationError: NSError?
        var copyError: Error?

        NSFileCoordinator().coordinate(
            readingItemAt: sourceURL,
            options: [.withoutChanges],
            error: &coordinationError
        ) { coordinatedURL in
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            console.log("Couldn't access \(sourceURL.lastPathComponent): \(coordinationError.localizedDescription)", type: .error)
            return nil
        }

        if let copyError {
            console.log("Couldn't import \(sourceURL.lastPathComponent): \(copyError.localizedDescription)", type: .error)
            return nil
        }

        console.log("Imported \(sourceURL.lastPathComponent)", type: .info)
        return destinationURL
    }

    private var importRoot: URL {
        let documents = try! fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documents.appendingPathComponent(".AzulaImports", isDirectory: true)
    }
}
