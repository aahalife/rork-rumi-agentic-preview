//
//  PasscodeView.swift
//  Rumi
//

import Combine
import SwiftUI

struct PasscodeView: View {
    let phone: String
    let onComplete: () -> Void
    let onChangeNumber: () -> Void

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var secondsLeft = 60
    @State private var submitted = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var countdownText: String {
        String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 40) {
                VStack(spacing: 12) {
                    Text("Check your phone,")
                        .font(.rumiTitle1)
                        .foregroundStyle(Color.labelPrimary)
                        .multilineTextAlignment(.center)

                    Text("We sent a 6-digit code by text to \(phone).")
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                VStack(spacing: 18) {
                    codeBoxes

                    resendLine
                }
            }
            .padding(.horizontal, .screenMargin)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        .onReceive(timer) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedIndex = 0
            }
        }
    }

    // MARK: Code boxes

    private var codeBoxes: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                TextField("", text: digitBinding(index))
                    .font(.rumiTitle2)
                    .foregroundStyle(Color.labelPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focusedIndex, equals: index)
                    .frame(width: 46, height: 56)
                    .background(Color.fillPrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.separator, lineWidth: 0.5)
                    )
                    .onChange(of: digits[index]) { oldValue, newValue in
                        handleDigitChange(at: index, oldValue: oldValue, newValue: newValue)
                    }
            }
        }
    }

    private func digitBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { digits[index] },
            set: { newValue in
                let cleaned = Array(newValue.filter { $0.isNumber }.prefix(6))
                if cleaned.count > 1 {
                    // Paste or rapid entry: distribute across boxes from here.
                    for (offset, character) in cleaned.enumerated() where index + offset < 6 {
                        digits[index + offset] = String(character)
                    }
                    focusedIndex = min(index + cleaned.count, 5)
                } else {
                    digits[index] = cleaned.last.map(String.init) ?? ""
                }
            }
        )
    }

    private func handleDigitChange(at index: Int, oldValue: String, newValue: String) {
        if newValue.isEmpty, !oldValue.isEmpty, index > 0 {
            focusedIndex = index - 1
        } else if !newValue.isEmpty, index < 5 {
            focusedIndex = index + 1
        }
        checkCompletion()
    }

    private func checkCompletion() {
        guard !submitted, digits.allSatisfy({ !$0.isEmpty }) else { return }
        submitted = true
        focusedIndex = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }

    // MARK: Resend / change number

    private var resendLine: some View {
        HStack(spacing: 4) {
            if secondsLeft > 0 {
                Text("Send a new code in \(countdownText)")
                    .foregroundStyle(Color.labelTertiary)
            } else {
                Button("Send a new code") {
                    digits = Array(repeating: "", count: 6)
                    submitted = false
                    secondsLeft = 60
                    focusedIndex = 0
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.labelPrimary)
            }

            Text("or")
                .foregroundStyle(Color.labelTertiary)

            Button("change number") {
                onChangeNumber()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.brandPrimary)
        }
    }
}

#Preview {
    PasscodeView(phone: "+1 555 123 4567", onComplete: {}, onChangeNumber: {})
}
