//
//  ContentView.swift
//  Azula
//
//  Created by Lilliana on 15/05/2023.
//

import SwiftUI

struct ContentView: View {
    @State private var useElleKit = true
    @State private var isImporting = false
    @State private var isPatching = false
    @State private var ipaURL: URL?
    @State private var dylibURLs: [URL] = []
    @State private var outputURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("Azula")
                            .font(.largeTitle.bold())
                        Text("Dylib injection for sideloaded iOS 27 apps")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            inputRow(title: "IPA", value: ipaURL?.lastPathComponent ?? "Not selected", icon: "shippingbox")
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
                            }
                            .buttonStyle(.bordered)
                        }
                    } label: {
                        Label("Inputs", systemImage: "square.and.arrow.down")
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("ElleKit compatibility", isOn: $useElleKit)
                            Text("For jailbreak-style tweaks, Azula stages ElleKit beside the tweak and rewrites common Substrate/libhooker paths to the local copy. Your original dylib files are not modified.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Label("Compatibility", systemImage: "wrench.and.screwdriver")
                    }

                    Button {
                        Task { await patch() }
                    } label: {
                        HStack {
                            if isPatching {
                                ProgressView()
                            } else {
                                Image(systemName: "hammer.fill")
                            }
                            Text(isPatching ? "Building Patched IPA…" : "Build Patched IPA")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(ipaURL == nil || dylibURLs.isEmpty || isPatching)

                    if let outputURL {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(outputURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)

                                Text("This output is intentionally unsigned. Open it in your normal iOS sideload signer, sign every embedded executable/dylib, then install it.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                ShareLink(item: outputURL) {
                                    Label("Share Patched IPA", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        } label: {
                            Label("Output", systemImage: "shippingbox.fill")
                        }
                    }

                    GroupBox {
                        ConsoleView()
                            .frame(minHeight: 180)
                    } label: {
                        Label("Patch Log", systemImage: "terminal")
                    }
                }
                .padding()
            }
            .navigationTitle("Azula")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isImporting) {
                FilePickerView(ipaURL: $ipaURL, dylibURLs: $dylibURLs, isShowing: $isImporting)
            }
        }
    }

    @ViewBuilder
    private func inputRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
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
