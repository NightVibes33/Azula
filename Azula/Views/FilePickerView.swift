//
//  FilePickerView.swift
//  Azula
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: View {
    @Binding var ipaURL: URL?
    @Binding var dylibURLs: [URL]
    @Binding var isShowing: Bool

    @State private var ipaImporting = false
    @State private var dylibImporting = false

    private let console: Console = .shared
    private let fileManager = FileManager.default

    // IMPORTANT: use the actual system/imported identifiers that existing
    // files in Files resolve to. Custom Azula-exported UTIs make existing
    // .ipa/.dylib files appear disabled because their content type does not
    // equal Azula's invented identifier.
    private static let ipaType = UTType(
        importedAs: "com.apple.itunes.ipa",
        conformingTo: .data
    )

    private static let dylibType = UTType(
        importedAs: "com.apple.mach-o-dylib",
        conformingTo: .data
    )

    var body: some View {
        NavigationStack {
            ZStack {
                AzulaBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 8) {
                            AzulaFlameMark(size: 62)
                            Text("Patch Files")
                                .font(.title.bold())
                                .foregroundStyle(AzulaTheme.warmWhite)

                            Text("IPA and dylib pickers use the real Apple file identifiers, then verify the filename extension before importing.")
                                .font(.footnote)
                                .foregroundStyle(AzulaTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)

                        AzulaSectionHeader(
                            title: "Target IPA",
                            subtitle: "Hardcoded type: com.apple.itunes.ipa"
                        )

                        AzulaCard {
                            VStack(alignment: .leading, spacing: 14) {
                                fileStatus(
                                    title: ipaURL == nil ? "No IPA selected" : "IPA selected",
                                    value: ipaURL?.lastPathComponent,
                                    icon: "shippingbox.fill",
                                    ready: ipaURL != nil
                                )

                                Button {
                                    ipaImporting = true
                                } label: {
                                    Label(ipaURL == nil ? "Choose .ipa" : "Replace .ipa", systemImage: "folder")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 48)
                                }
                                .buttonStyle(AzulaSecondaryButtonStyle())
                            }
                        }

                        AzulaSectionHeader(
                            title: "Injected Dylibs",
                            subtitle: "Hardcoded type: com.apple.mach-o-dylib"
                        )

                        AzulaCard {
                            VStack(alignment: .leading, spacing: 14) {
                                fileStatus(
                                    title: dylibURLs.isEmpty ? "No dylibs selected" : "Dylibs selected",
                                    value: dylibURLs.isEmpty ? nil : "\(dylibURLs.count) selected",
                                    icon: "puzzlepiece.extension.fill",
                                    ready: !dylibURLs.isEmpty
                                )

                                ForEach(dylibURLs, id: \.self) { url in
                                    HStack(spacing: 10) {
                                        Image(systemName: "doc.badge.gearshape")
                                            .foregroundStyle(AzulaTheme.orange)

                                        Text(url.lastPathComponent)
                                            .font(.footnote)
                                            .foregroundStyle(AzulaTheme.secondaryText)
                                            .lineLimit(2)
                                            .truncationMode(.middle)

                                        Spacer()

                                        Button(role: .destructive) {
                                            dylibURLs.removeAll { $0 == url }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10)
                                    .background(
                                        Color.black.opacity(0.22),
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    )
                                }

                                Button {
                                    dylibImporting = true
                                } label: {
                                    Label(dylibURLs.isEmpty ? "Choose .dylib" : "Change .dylib files", systemImage: "folder.badge.plus")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 48)
                                }
                                .buttonStyle(AzulaSecondaryButtonStyle())
                            }
                        }
                    }
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
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
        .fileImporter(
            isPresented: $ipaImporting,
            allowedContentTypes: [Self.ipaType],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let sourceURL = urls.first else { return }
                guard validateSelectedFile(sourceURL, requiredExtension: "ipa") else { return }
                ipaURL = importFile(sourceURL, folder: "IPA")
            case .failure(let error):
                console.log("IPA import failed: \(error.localizedDescription)", type: .error)
            }
        }
        .fileImporter(
            isPresented: $dylibImporting,
            allowedContentTypes: [Self.dylibType],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let valid = urls.filter {
                    validateSelectedFile($0, requiredExtension: "dylib", logFailure: false)
                }

                for rejected in urls where !valid.contains(rejected) {
                    console.log("Skipped non-dylib file: \(rejected.lastPathComponent)", type: .warn)
                }

                guard !valid.isEmpty else {
                    console.log("No .dylib files were selected", type: .error)
                    return
                }

                dylibURLs = importDylibs(valid)
            case .failure(let error):
                console.log("Dylib import failed: \(error.localizedDescription)", type: .error)
            }
        }
    }

    @ViewBuilder
    private func fileStatus(title: String, value: String?, icon: String, ready: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AzulaTheme.fireGradient)
                .frame(width: 46, height: 46)
                .background(
                    AzulaTheme.orange.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AzulaTheme.warmWhite)

                if let value {
                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(AzulaTheme.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                if ready {
                    AzulaStatusBadge(
                        text: "Ready",
                        systemImage: "checkmark.circle.fill",
                        tint: AzulaTheme.gold
                    )
                    .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func validateSelectedFile(
        _ sourceURL: URL,
        requiredExtension: String,
        logFailure: Bool = true
    ) -> Bool {
        guard sourceURL.pathExtension.caseInsensitiveCompare(requiredExtension) == .orderedSame else {
            if logFailure {
                console.log(
                    "Expected a .\(requiredExtension) file, got \(sourceURL.lastPathComponent)",
                    type: .error
                )
            }
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

            if let destination = copySecurityScopedFile(
                sourceURL,
                to: root.appendingPathComponent(name)
            ) {
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

        return copySecurityScopedFile(
            sourceURL,
            to: root.appendingPathComponent(sourceURL.lastPathComponent)
        )
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
            console.log(
                "Couldn't access \(sourceURL.lastPathComponent): \(coordinationError.localizedDescription)",
                type: .error
            )
            return nil
        }

        if let copyError {
            console.log(
                "Couldn't import \(sourceURL.lastPathComponent): \(copyError.localizedDescription)",
                type: .error
            )
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
