//
//  Patcher.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import Foundation

struct Patcher {
    let targetURL: URL
    private let console: Console = .shared

    func patch(_ patches: [Patch]) -> Bool {
        guard !patches.isEmpty else {
            console.log("No binary changes required", type: .info)
            return true
        }

        guard let handle = try? FileHandle(forWritingTo: targetURL) else {
            console.log("Couldn't get write handle to \(targetURL.path)", type: .error)
            return false
        }

        do {
            var currentOffset: UInt64 = 0

            for patch in patches {
                if let offset = patch.offset {
                    guard offset >= 0 else {
                        console.log("Negative patch offset", type: .error)
                        try handle.close()
                        return false
                    }
                    currentOffset = UInt64(offset)
                    try handle.seek(toOffset: currentOffset)
                }

                console.log(String(format: "Patching 0x%X bytes at 0x%X", patch.data.count, currentOffset), type: .info)
                try handle.write(contentsOf: patch.data)
                currentOffset += UInt64(patch.data.count)
            }

            try handle.close()
        } catch {
            try? handle.close()
            console.log(error.localizedDescription, type: .error)
            return false
        }

        return true
    }
}
