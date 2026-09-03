//
//  LogMessageView.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import SwiftUI

struct LogMessageView: View {
    let log: Log

    private var marker: String {
        switch log.type {
        case .info:
            return "[*]"
        case .warn, .error:
            return "[!]"
        }
    }

    private var markerColor: Color {
        switch log.type {
        case .info:
            return .green
        case .warn:
            return .yellow
        case .error:
            return .red
        }
    }

    private var spokenType: String {
        switch log.type {
        case .info:
            return "Info"
        case .warn:
            return "Warning"
        case .error:
            return "Error"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(marker)
                .foregroundStyle(markerColor)
                .font(.system(.footnote, design: .monospaced, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityHidden(true)

            Text(log.message)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spokenType): \(log.message)")
    }
}
