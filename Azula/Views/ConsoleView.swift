//
//  ConsoleView.swift
//  Azula
//
//  Created by Lilliana on 16/05/2023.
//

import SwiftUI

struct ConsoleView: View {
    @StateObject private var console: Console = .shared

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 360
            let padding: CGFloat = compact ? 10 : 14

            ZStack {
                RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                if console.logs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("Patch activity will appear here")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(padding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            LazyVStack(alignment: .leading, spacing: compact ? 9 : 12) {
                                ForEach(console.logs, id: \.self) { log in
                                    LogMessageView(log: log)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id("AZULA_LOG_BOTTOM")
                            }
                            .padding(padding)
                        }
                        .scrollIndicators(.automatic)
                        .onChange(of: console.logs.count) { _ in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("AZULA_LOG_BOTTOM", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 18, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Patch log")
    }
}
