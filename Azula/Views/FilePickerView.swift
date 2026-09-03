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
            GeometryReader { geometry in
                let compact = geometry.size.width < 375
                let accessibilityText = dynamicTypeSize.isAccessibilitySize
                let rowPadding: CGFloat = accessibilityText ? 10 : (compact ? 5 : 8)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Form {
                        Section("Decrypted IPA") {
                            Button {
                                ipaImporting = true
                            } label: {
                                selectionRow(
                                    title: ipaURL == nil ? "Choose IPA" : "Selected IPA",
                                    value: ipaURL?.lastPathComponent,
                                    icon: "shippingbox"
                                )
                                .padding(.vertical, rowPadding)
                            }
                            .fileImporter(
                                isPresented: $ipaImporting,
                                allowedContentTypes: [UTType(filenameExtension: "ipa")!]
                            ) { result in
                                switch result {
                                case .success(let sourceURL):
                                    ipaURL = importFile(sourceURL, folder: "IPA")
                                case .failure(let error):
                                    console.log("IPA import failed: \(error.localizedDescription)", type: .error)
                                }
                            }
                        }

                        Section("Dylibs") {
                            Button {
                                dylibImporting = true
                            } label: {
                                selectionRow(
                                    title: dylibURLs.isEmpty ? "Choose Dylibs" : "Change Dylibs",
                                    value: dylibURLs.isEmpty ? nil : "\(dylibURLs.count) selected",
                                    icon: "puzzlepiece.extension"
                                )
                                .padding(.vertical, rowPadding)
                            }
                            .fileImporter(
                                isPresented: $dylibImporting,
                                allowedContentTypes: [UTType(filenameExtension: "dylib")!],
                                allowsMultipleSelection: true
                            ) { result in
                                switch result {
                                case .success(let sourceURLs):
                                    dylibURLs = importDylibs(sourceURLs)
                                case .failure(let error):
                                    console.log("Dylib import failed: \(error.localizedDescription)", type: .error)
                                }
                            }

                            ForEach(dylibURLs, id: \.self) { url in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: "doc.badge.gearshape")
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)

                                    Text(url.lastPathComponent)
                                        .font(.footnote)
                                        .lineLimit(accessibilityText ? 4 : 2)
                                        .truncationMode(.middle)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, compact ? 2 : 4)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        dylibURLs.removeAll { $0 == url }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }

                        Section {
                            Label {
                                Text("Azula copies selected files into its own sandbox before patching. The originals in Files are never modified.")
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "checkmark.shield")
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 700)

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Patch Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isShowing = false }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowing = false }
                        .fontWeight(.semibold)
                        .disabled(ipaURL == nil || dylibURLs.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func selectionRow(title: String, value: String?, icon: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if let value {
                        Text(value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.body.weight(.medium))
                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
