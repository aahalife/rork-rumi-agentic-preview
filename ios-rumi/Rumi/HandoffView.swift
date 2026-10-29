//
//  HandoffView.swift
//  Rumi
//

import SwiftUI

struct HandoffView: View {
    let onOpenMessages: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 28) {
                // Success glyph
                ZStack {
                    Circle()
                        .fill(Color.fillTertiary)
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.rumiTitle1.weight(.semibold))
                        .foregroundStyle(Color.brandPrimary)
                }

                VStack(spacing: 12) {
                    Text("You're all set.")
                        .font(.rumiTitle1)
                        .foregroundStyle(Color.labelPrimary)
                        .multilineTextAlignment(.center)

                    Text("Rumi lives in your Messages app. Tap below to start.")
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, .screenMargin)

            Spacer(minLength: 0)

            // TODO: iMessage handoff — replace this placeholder navigation with
            // opening the sms:/imessage URL scheme (e.g. UIApplication.shared.open)
            // once the Messages app flow is built.
            Button {
                onOpenMessages()
            } label: {
                HStack(spacing: 8) {
                    Image("IMessageIcon")
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text("Open iMessage")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.brandPrimary)
            .font(.rumiHeadline)
            .padding(.horizontal, .screenMargin)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    HandoffView(onOpenMessages: {})
}
