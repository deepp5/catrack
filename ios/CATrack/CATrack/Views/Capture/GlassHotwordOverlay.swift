//
//  GlassHotwordOverlay.swift
//  CATrack
//
//  Created by Vishrut Patel on 2/28/26.
//

import SwiftUI

struct GlassHotwordOverlay: View {
    let stateText: String
    let confirmed: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: confirmed ? "checkmark.circle.fill" : "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(confirmed ? Color.severityPass : Color.catYellow)

                Text(stateText)
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()
            }

            Text(confirmed ? "Command captured." : "Listening…")
                .font(.dmMono(11))
                .foregroundStyle(Color.appMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(radius: 12)
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
}
