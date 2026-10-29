//
//  ContentView.swift
//  Rumi
//

import SwiftUI

enum AppRoute: Hashable {
    case auth(AuthFlow)
    case otp(phone: String)
    case handoff
}

struct ContentView: View {
    @State private var isOnboarded = false

    var body: some View {
        if isOnboarded {
            HomeView()
        } else {
            WelcomeView(onFinish: { isOnboarded = true })
        }
    }
}

struct WelcomeView: View {
    let onFinish: () -> Void

    @State private var appeared = false
    @State private var path: [AppRoute] = []
    @State private var phone = ""
    @State private var country = Country(iso: "US", name: "United States", dialCode: "+1")

    var body: some View {
        NavigationStack(path: $path) {
        VStack(spacing: 0) {
            // Wordmark placeholder — tap to skip ahead to the chat surface.
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.brandPrimary)
                    .frame(width: 34, height: 6)
                Text("Rumi")
                    .font(.rumiTitle3)
                    .foregroundStyle(Color.labelPrimary)
            }
            .padding(.top, 24)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -8)
            .contentShape(Rectangle())
            .onTapGesture { onFinish() }

            Spacer(minLength: 0)

            // Statement
            VStack(spacing: 16) {
                Text("Welcome to Rumi,")
                    .font(.rumiLargeTitle)
                    .foregroundStyle(Color.labelPrimary)
                    .multilineTextAlignment(.center)

                Text("A health companion that gets to know you, and quietly helps along the way.")
                    .font(.rumiBody)
                    .foregroundStyle(Color.labelSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 300)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)

            Spacer(minLength: 0)

            // Actions
            VStack(spacing: 18) {
                Button {
                    path.append(.auth(.newUser))
                } label: {
                    Text("Say hello")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(.brandPrimary)
                    .font(.rumiHeadline)

                Button {
                    path.append(.auth(.returningUser))
                } label: {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.borderless)
                    .controlSize(.large)
                    .tint(.brandPrimary)
                    .font(.rumiHeadline)
            }
            .padding(.bottom, 28)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .padding(.horizontal, .screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .auth(let flow):
                PhoneEntryView(
                    flow: flow,
                    phone: $phone,
                    country: $country,
                    onContinue: { fullPhone in
                        path.append(.otp(phone: fullPhone))
                    }
                )
            case .otp(let phone):
                PasscodeView(
                    phone: phone,
                    onComplete: { path.append(.handoff) },
                    onChangeNumber: { path.removeLast() }
                )
            case .handoff:
                HandoffView(onOpenMessages: onFinish)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        }
    }
}

#Preview {
    ContentView()
}

#Preview {
    WelcomeView(onFinish: {})
}
