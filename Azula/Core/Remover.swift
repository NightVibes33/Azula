//
//  Remover.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import Foundation
import MachO

struct Remover {
    let extractor: Extractor
    let patcher: Patcher
    private let console: Console = .shared

    func replace(_ payloads: [String], with replacement: String) -> Bool {
        guard !payloads.isEmpty else { return true }

        let dylibCommands: [DylibCommand] = loadCommands.lazy.compactMap { $0 as? DylibCommand }
        var patches: [Patch] = []
        let replacementBytes = Data(replacement.utf8)

        for command in dylibCommands {
            let loadStringOffset = Int(command.command.dylib.name.offset)
            let stringOffset = command.offset + loadStringOffset
            let capacity = Int(command.command.cmdsize) - loadStringOffset

            guard capacity > 0,
                  let data = extractor.extractRaw(offset: stringOffset, length: capacity),
                  let currentPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters),
                  payloads.contains(currentPath)
            else {
                continue
            }

            guard replacementBytes.count + 1 <= capacity else {
                console.log("Replacement path is too long for \(currentPath)", type: .error)
                return false
            }

            var pathData = Data(repeating: 0, count: capacity)
            pathData.replaceSubrange(0 ..< replacementBytes.count, with: replacementBytes)
            patches.append(Patch(offset: stringOffset, data: pathData))
            console.log("Rewriting \(currentPath) → \(replacement)", type: .info)
        }

        return patcher.patch(patches)
    }

    // Kept for source compatibility. Blank dylib paths are not valid on modern
    // iOS, so callers should use replace(_:with:) instead.
    func remove(_ payloads: [String]) -> Bool {
        guard payloads.isEmpty else {
            console.log("Direct dylib removal is disabled; rewrite the dependency path instead", type: .warn)
            return false
        }
        return true
    }
}
