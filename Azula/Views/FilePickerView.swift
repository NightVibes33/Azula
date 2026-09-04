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

    // Keep the real Apple identifiers, but include provider fallbacks.
    // Files providers are allowed to surface an IPA as an archive/data file
    // and a dylib as an executable/data file. A strict single-UTI picker can
    // therefore gray out a perfectly valid file before Azula ever sees it.
    private static let ipaType = UTType(
        importedAs: "com.apple.itunes.ipa",
        conformingTo: .data
    )

    private static let dylibType = UTType(
        importedAs: "com.apple.mach-o-dylib",
        conformingTo: .data
    )

    private static let ipaPickerTypes: [UTType] = [
        ipaType,
        .zip,
        .archive,
        .data
    ]

    private static let dylibPickerTypes: [UTType] = [
        dylibType,
        .unixExecutable,
        .data
    ]

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

                            Text("Files providers can report IPA and dylib files under broader system types. Azula accepts those provider types, then strictly verifies the extension and file signature before importing.")
                                .font(.footnote)
                                .foregroundStyle(AzulaTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)

                        AzulaSectionHeader(
                            title: "Target IPA",
                            subtitle: "Select an .ipa file. Azula verifies that it is a ZIP-based IPA container."
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
                            subtitle: "Select one or more .dylib files. Azula verifies Mach-O magic before accepting them."
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
            allowedContentTypes: Self.ipaPickerTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let sourceURL = urls.first else { return }
                guard validateSelectedFile(sourceURL, requiredExtension: "ipa") else { return }
                guard let imported = importFile(sourceURL, folder: "IPA") else { return }

                guard isValidIPA(imported) else {
                    try? fileManager.removeItem(at: imported)
                    console.log("Rejected \(sourceURL.lastPathComponent): the file does not have a valid ZIP/IPA signature", type: .error)
                    return
                }

                ipaURL = imported
                console.log("Validated IPA: \(sourceURL.lastPathComponent)", type: .info)

            case .failure(let error):
                console.log("IPA import failed: \(error.localizedDescription)", type: .error)
            }
        }
        .fileImporter(
            isPresented: $dylibImporting,
            allowedContentTypes: Self.dylibPickerTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let extensionValid = urls.filter {
                    validateSelectedFile($0, requiredExtension: "dylib", logFailure: false)
                }

                for rejected in urls where !extensionValid.contains(rejected) {
                    console.log("Skipped non-dylib file: \(rejected.lastPathComponent)", type: .warn)
                }

                guard !extensionValid.isEmpty else {
                    console.log("No .dylib files were selected", type: .error)
                    return
                }

                dylibURLs = importDylibs(extensionValid)

            case .failure(let error):
                console.log("Dylib import failed: \(error.localizedDescription)", type: .error)
            }
        }
        .fileDialogBrowserOptions(.displayFileExtensions)
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

            guard let destination = copySecurityScopedFile(
                sourceURL,
                to: root.appendingPathComponent(name)
            ) else {
                continue
            }

            guard isValidMachO(destination) else {
                try? fileManager.removeItem(at: destination)
                console.log("Rejected \(name): the file does not have a Mach-O/fat Mach-O signature", type: .error)
                continue
            }

            console.log("Validated dylib: \(name)", type: .info)
            imported.append(destination)
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

    private func firstBytes(of url: URL, count: Int = 4) -> [UInt8] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: count), let data else { return [] }
        return Array(data)
    }

    private func isValidIPA(_ url: URL) -> Bool {
        let bytes = firstBytes(of: url)
        guard bytes.count >= 4 else { return false }

        return bytes == [0x50, 0x4B, 0x03, 0x04] ||
               bytes == [0x50, 0x4B, 0x05, 0x06] ||
               bytes == [0x50, 0x4B, 0x07, 0x08]
    }

    private func isValidMachO(_ url: URL) -> Bool {
        let bytes = firstBytes(of: url)
        guard bytes.count >= 4 else { return false }

        let acceptedMagics: [[UInt8]] = [
            [0xFE, 0xED, 0xFA, 0xCE], // MH_MAGIC
            [0xCE, 0xFA, 0xED, 0xFE], // MH_CIGAM
            [0xFE, 0xED, 0xFA, 0xCF], // MH_MAGIC_64
            [0xCF, 0xFA, 0xED, 0xFE], // MH_CIGAM_64
            [0xCA, 0xFE, 0xBA, 0xBE], // FAT_MAGIC
            [0xBE, 0xBA, 0xFE, 0xCA], // FAT_CIGAM
            [0xCA, 0xFE, 0xBA, 0xBF], // FAT_MAGIC_64
            [0xBF, 0xBA, 0xFE, 0xCA]  // FAT_CIGAM_64
        ]

        return acceptedMagics.contains(bytes)
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
