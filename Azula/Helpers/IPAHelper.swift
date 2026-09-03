//
//  IPAHelper.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import Foundation
import ZIPFoundation

private let documentsURL: URL = try! FileManager.default.url(
    for: .documentDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
)

struct IPAHelper {
    let url: URL
    private let console: Console = .shared
    private let fileManager = FileManager.default

    private var workURL: URL {
        fileManager.temporaryDirectory.appendingPathComponent("AzulaWorkspace", isDirectory: true)
    }

    private var payloadURL: URL {
        workURL.appendingPathComponent("Payload", isDirectory: true)
    }

    func getBinaryURL() -> URL? {
        do {
            if fileManager.fileExists(atPath: workURL.path) {
                try fileManager.removeItem(at: workURL)
            }
            try fileManager.createDirectory(at: workURL, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: url, to: workURL)
        } catch {
            console.log("Couldn't unpack IPA: \(error.localizedDescription)", type: .error)
            return nil
        }

        guard let appURL = mainAppURL() else { return nil }

        if let executableURL = Bundle(url: appURL)?.executableURL,
           fileManager.fileExists(atPath: executableURL.path)
        {
            console.log("Target executable: \(executableURL.lastPathComponent)", type: .info)
            return executableURL
        }

        // Bundle(url:) can fail on unusual decrypted packages. Fall back to
        // CFBundleExecutable from Info.plist rather than guessing from App.app.
        let infoURL = appURL.appendingPathComponent("Info.plist")
        if let info = NSDictionary(contentsOf: infoURL) as? [String: Any],
           let executable = info["CFBundleExecutable"] as? String,
           !executable.isEmpty
        {
            let executableURL = appURL.appendingPathComponent(executable)
            if fileManager.fileExists(atPath: executableURL.path) {
                console.log("Target executable: \(executable)", type: .info)
                return executableURL
            }
        }

        console.log("Couldn't resolve CFBundleExecutable in target app", type: .error)
        return nil
    }

    @discardableResult
    func addDylib(_ dylibURL: URL, named customName: String? = nil) -> URL? {
        guard let appURL = mainAppURL() else { return nil }

        let frameworksURL = appURL.appendingPathComponent("Frameworks", isDirectory: true)
        let name = customName ?? dylibURL.lastPathComponent
        let destinationURL = frameworksURL.appendingPathComponent(name)

        do {
            try fileManager.createDirectory(at: frameworksURL, withIntermediateDirectories: true)

            // Never destroy an app's existing embedded framework/dylib merely
            // because an imported tweak happens to use the same filename.
            if fileManager.fileExists(atPath: destinationURL.path) {
                console.log("Frameworks already contains \(name); refusing to overwrite it", type: .error)
                return nil
            }

            try fileManager.copyItem(at: dylibURL, to: destinationURL)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
            console.log("Staged \(name) in Frameworks", type: .info)
            return destinationURL
        } catch {
            console.log("Couldn't stage \(name): \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    func repackIPA() -> URL? {
        let baseName = url.deletingPathExtension().lastPathComponent
        let outputURL = documentsURL.appendingPathComponent("\(baseName)-AzulaPatched.ipa")

        do {
            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }

            guard fileManager.fileExists(atPath: payloadURL.path) else {
                console.log("Patch workspace is missing Payload", type: .error)
                return nil
            }

            try fileManager.zipItem(
                at: payloadURL,
                to: outputURL,
                shouldKeepParent: true,
                compressionMethod: .deflate
            )

            guard fileManager.fileExists(atPath: outputURL.path) else {
                console.log("Patched IPA was not created", type: .error)
                return nil
            }

            console.log("Unsigned patched IPA saved to Files: \(outputURL.lastPathComponent)", type: .info)
            return outputURL
        } catch {
            console.log("Couldn't repack IPA: \(error.localizedDescription)", type: .error)
            return nil
        }
    }

    private func mainAppURL() -> URL? {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: payloadURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let apps = contents.filter { url in
                guard url.pathExtension.lowercased() == "app" else { return false }
                return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }

            guard apps.count == 1, let appURL = apps.first else {
                console.log(
                    apps.isEmpty ? "Couldn't find an .app inside Payload" : "IPA contains multiple top-level .app bundles",
                    type: .error
                )
                return nil
            }

            return appURL
        } catch {
            console.log("Couldn't inspect Payload: \(error.localizedDescription)", type: .error)
            return nil
        }
    }
}
