//
//  Azula.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import Foundation
import MachO

var loadCommands: [any LoadCommand] = []
var machHeaders: [MachHeader] = []

struct Azula {
    private let console: Console = .shared
    private let extractor: Extractor
    private let injector: Injector
    private let patcher: Patcher
    private let payloads: [String]
    private let remPayloads: [String]
    private let remover: Remover
    private let target: Data
    private let url: URL

    init(
        injecting payloads: [String],
        removing remPayloads: [String],
        from url: URL
    ) {
        self.payloads = payloads
        self.remPayloads = remPayloads
        self.url = url
        target = (try? Data(contentsOf: url)) ?? Data()
        extractor = Extractor(target: target)
        patcher = Patcher(targetURL: url)
        injector = Injector(extractor: extractor, patcher: patcher)
        remover = Remover(extractor: extractor, patcher: patcher)

        // These collections are parser state for one target only. The original
        // implementation leaked commands between successive binaries.
        loadCommands.removeAll(keepingCapacity: true)
        machHeaders.removeAll(keepingCapacity: true)

        guard !target.isEmpty else {
            console.log("Couldn't read target binary", type: .error)
            return
        }

        guard let fatHeader: fat_header = extractor.extract() else {
            console.log("Couldn't find Mach-O header", type: .error)
            return
        }

        if fatHeader.magic.byteSwapped == FAT_MAGIC {
            let archCount = _OSSwapInt32(fatHeader.nfat_arch)
            var offset = MemoryLayout<fat_header>.size

            console.log("Multi-architecture binary with \(archCount) slices", type: .info)

            for _ in 0 ..< archCount {
                guard let arch: fat_arch = extractor.extract(at: offset) else {
                    console.log("Couldn't parse fat architecture table", type: .error)
                    return
                }

                let archOffset = Int(_OSSwapInt32(arch.offset))
                if let header: mach_header_64 = extractor.extract(at: archOffset),
                   header.magic == MH_MAGIC_64 || header.magic == MH_CIGAM_64
                {
                    let mh = MachHeader(header: header, offset: archOffset)
                    machHeaders.append(mh)
                    loadCommands.append(contentsOf: getLoadCommands(for: mh))
                }

                offset += MemoryLayout<fat_arch>.size
            }
        } else if let header: mach_header_64 = extractor.extract(),
                  header.magic == MH_MAGIC_64 || header.magic == MH_CIGAM_64
        {
            console.log("Thin binary", type: .info)
            let mh = MachHeader(header: header, offset: 0)
            machHeaders = [mh]
            loadCommands = getLoadCommands(for: mh)
        } else {
            console.log("Unsupported or malformed Mach-O binary", type: .error)
        }
    }

    func inject() -> Bool {
        guard !machHeaders.isEmpty else {
            console.log("No valid Mach-O slices found", type: .error)
            return false
        }

        guard !isEncrypted() else {
            console.log("Azula requires a decrypted IPA binary", type: .error)
            return false
        }

        let deviceHeaders = machHeaders.filter { $0.header.cputype == CPU_TYPE_ARM64 }
        guard !deviceHeaders.isEmpty else {
            console.log("No arm64/arm64e device slice found", type: .error)
            return false
        }

        for (payload, mh) in product(payloads, deviceHeaders) {
            guard injector.inject(payload, withHeader: mh),
                  let binName = payload.components(separatedBy: "/").last,
                  let archName = getArchName(for: mh.header)
            else {
                return false
            }

            console.log("Injected \(binName) into \(archName) slice", type: .info)
        }

        return true
    }

    func remove() -> Bool {
        remover.remove(remPayloads)
    }

    func replaceLoadPaths(_ oldPaths: [String], with replacement: String) -> Bool {
        remover.replace(oldPaths, with: replacement)
    }

    func slice() -> Bool {
        let signatureLoadCommands: [SignatureCommand] = loadCommands.lazy.compactMap { $0 as? SignatureCommand }
        var patches: [Patch] = []
        var strip = 0x0000_1337

        for command in signatureLoadCommands {
            patches.append(Patch(offset: command.offset, data: Data(bytes: &strip, count: 4)))
        }

        return patcher.patch(patches)
    }

    private func getLoadCommands(for mh: MachHeader) -> [any LoadCommand] {
        var offset = mh.offset + MemoryLayout.size(ofValue: mh.header)
        var result: [any LoadCommand] = []

        for _ in 0 ..< mh.header.ncmds {
            guard let loadCommand: load_command = extractor.extract(at: offset),
                  loadCommand.cmdsize >= UInt32(MemoryLayout<load_command>.size)
            else {
                console.log(String(format: "Invalid load command at 0x%X", offset), type: .error)
                return result
            }

            switch loadCommand.cmd {
            case UInt32(LC_LOAD_DYLIB),
                 UInt32(LC_LOAD_WEAK_DYLIB),
                 UInt32(LC_REEXPORT_DYLIB),
                 UInt32(LC_LOAD_UPWARD_DYLIB),
                 UInt32(LC_LAZY_LOAD_DYLIB):
                guard let command: dylib_command = extractor.extract(at: offset) else { return result }
                result.append(DylibCommand(offset: offset, command: command, mh: mh))

            case UInt32(LC_ENCRYPTION_INFO_64):
                guard let command: encryption_info_command_64 = extractor.extract(at: offset) else { return result }
                result.append(EncryptionCommand(offset: offset, command: command))

            case UInt32(LC_CODE_SIGNATURE):
                guard let command: linkedit_data_command = extractor.extract(at: offset) else { return result }
                result.append(SignatureCommand(offset: offset, command: command))

            case UInt32(LC_SEGMENT_64):
                guard let command: segment_command_64 = extractor.extract(at: offset) else { return result }
                result.append(SegmentCommand(offset: offset, command: command, mh: mh))

            default:
                break
            }

            offset += Int(loadCommand.cmdsize)
        }

        return result
    }

    private func isEncrypted() -> Bool {
        let encryptionCommands: [EncryptionCommand] = loadCommands.lazy.compactMap { $0 as? EncryptionCommand }
        return encryptionCommands.contains { $0.command.cryptid != 0 }
    }

    private func getArchName(for header: mach_header_64) -> String? {
        guard header.cputype == CPU_TYPE_ARM64 else { return nil }
        return header.cpusubtype == CPU_SUBTYPE_ARM64E ? "arm64e" : "arm64"
    }

    private func product<T, U>(_ a: [T], _ b: [U]) -> [(T, U)] {
        var result: [(T, U)] = []
        for first in a {
            for second in b {
                result.append((first, second))
            }
        }
        return result
    }
}
