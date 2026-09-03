//
//  Injector.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import Foundation
import MachO

struct Injector {
    let extractor: Extractor
    let patcher: Patcher
    private let console: Console = .shared

    func inject(
        _ payload: String,
        withHeader mh: MachHeader
    ) -> Bool {
        let stringLength = payload.utf8.count + 1
        let alignedStringLength = (stringLength + 7) & ~7
        let payloadSize = MemoryLayout<dylib_command>.size + alignedStringLength
        let commandOffset = mh.offset + MemoryLayout<mach_header_64>.size + Int(mh.header.sizeofcmds)

        if isAlreadyInjected(payload, in: mh) {
            console.log("Payload is already injected in this slice", type: .info)
            return true
        }

        guard hasSpace(for: payloadSize, in: mh) else {
            console.log("Not enough Mach-O header space to inject \(payload)", type: .error)
            return false
        }

        var dylibCmd = dylib_command()
        var newHeader = mh.header

        dylibCmd.cmd = LC_LOAD_WEAK_DYLIB
        dylibCmd.cmdsize = UInt32(payloadSize)
        dylibCmd.dylib.name = lc_str(offset: UInt32(MemoryLayout<dylib_command>.size))

        newHeader.ncmds += 1
        newHeader.sizeofcmds += UInt32(payloadSize)

        if let index = machHeaders.firstIndex(where: { $0.offset == mh.offset }) {
            machHeaders[index] = MachHeader(header: newHeader, offset: mh.offset)
        }

        var commandData = Data(bytes: &dylibCmd, count: MemoryLayout<dylib_command>.size)
        commandData.append(contentsOf: payload.utf8)
        commandData.append(0)
        if commandData.count < payloadSize {
            commandData.append(Data(repeating: 0, count: payloadSize - commandData.count))
        }

        let patches: [Patch] = [
            Patch(offset: mh.offset, data: Data(bytes: &newHeader, count: MemoryLayout<mach_header_64>.size)),
            Patch(offset: commandOffset, data: commandData),
        ]

        return patcher.patch(patches)
    }

    private func hasSpace(
        for payloadSize: Int,
        in mh: MachHeader
    ) -> Bool {
        let segmentCommands = loadCommands.lazy
            .compactMap { $0 as? SegmentCommand }
            .filter { $0.mh.offset == mh.offset }

        let textSegment = segmentCommands.first { segment in
            var segname = segment.command.segname
            return withUnsafeBytes(of: &segname) { bytes in
                guard let baseAddress = bytes.baseAddress else { return false }
                return strcmp(baseAddress.assumingMemoryBound(to: CChar.self), "__TEXT") == 0
            }
        }

        guard let textSegment else {
            console.log("Couldn't find __TEXT segment for this architecture", type: .error)
            return false
        }

        var firstSectionOffset: UInt32?
        for index in 0 ..< textSegment.command.nsects {
            let sectionOffset = textSegment.offset
                + MemoryLayout<segment_command_64>.size
                + MemoryLayout<section_64>.size * Int(index)

            guard let section: section_64 = extractor.extract(at: sectionOffset) else {
                return false
            }

            guard section.offset > 0 else { continue }
            if let current = firstSectionOffset {
                firstSectionOffset = min(current, section.offset)
            } else {
                firstSectionOffset = section.offset
            }
        }

        guard let firstSectionOffset else {
            console.log("Couldn't locate the first __TEXT section", type: .error)
            return false
        }

        let usedHeaderBytes = UInt32(MemoryLayout<mach_header_64>.size) + mh.header.sizeofcmds
        guard firstSectionOffset >= usedHeaderBytes else {
            console.log("Invalid Mach-O header layout", type: .error)
            return false
        }

        let available = Int(firstSectionOffset - usedHeaderBytes)
        console.log(String(format: "Header space available in slice: 0x%X", available), type: .info)
        return available >= payloadSize
    }

    private func isAlreadyInjected(_ payload: String, in mh: MachHeader) -> Bool {
        let dylibCommands = loadCommands.lazy
            .compactMap { $0 as? DylibCommand }
            .filter { $0.mh.offset == mh.offset }

        for dylibCommand in dylibCommands {
            let loadStringOffset = Int(dylibCommand.command.dylib.name.offset)
            let stringOffset = dylibCommand.offset + loadStringOffset
            let length = Int(dylibCommand.command.cmdsize) - loadStringOffset

            guard length > 0,
                  let data = extractor.extractRaw(offset: stringOffset, length: length),
                  let currentPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
            else {
                console.log("Couldn't read an existing dylib load command", type: .warn)
                continue
            }

            if currentPath == payload {
                return true
            }

            if currentPath.components(separatedBy: "/").last == payload.components(separatedBy: "/").last {
                console.log("A dylib with the same filename is already referenced at \(currentPath)", type: .warn)
            }
        }

        return false
    }
}
