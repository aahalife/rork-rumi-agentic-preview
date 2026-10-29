//
//  PhoneEntryView.swift
//  Rumi
//

import SwiftUI

enum AuthFlow: Hashable {
    case newUser
    case returningUser
}

struct Country: Identifiable, Hashable {
    let iso: String
    let name: String
    let dialCode: String

    var id: String { iso }
    var flag: String {
        let base: UInt32 = 0x1F1E6
        return iso.uppercased().unicodeScalars
            .compactMap { UnicodeScalar(base + $0.value - 65) }
            .map(String.init)
            .joined()
    }
}

struct PhoneEntryView: View {
    let flow: AuthFlow
    @Binding var phone: String
    @Binding var country: Country
    let onContinue: (_ fullPhone: String) -> Void

    @FocusState private var fieldFocused: Bool
    @State private var showingCountryPicker = false
    @State private var presentedURL: PresentedURL?

    private var header: String {
        switch flow {
        case .newUser: "Let's get you set up"
        case .returningUser: "Welcome back"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 40) {
                VStack(spacing: 12) {
                    Text(header)
                        .font(.rumiTitle1)
                        .foregroundStyle(Color.labelPrimary)
                        .multilineTextAlignment(.center)

                    Text("We'll text you a code to confirm it's you.")
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                VStack(spacing: 16) {
                    phoneField

                    Text("By tapping 'Continue,' you agree to Rumi's [Terms of Service](https://example.com/terms) and [SMS Terms](https://example.com/sms-terms), and acknowledge the [Privacy Policy](https://example.com/privacy).")
                        .font(.rumiFootnote)
                        .foregroundStyle(Color.labelTertiary)
                        .tint(.brandPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 12)
                        .environment(\.openURL, OpenURLAction { url in
                            presentedURL = PresentedURL(url: url)
                            return .handled
                        })
                }
            }
            .padding(.horizontal, .screenMargin)

            Spacer(minLength: 0)

            Button {
                onContinue("\(country.dialCode) \(phone)")
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.brandPrimary)
                .font(.rumiHeadline)
                .disabled(phone.trimmingCharacters(in: .whitespaces).count < 7)
                .padding(.horizontal, .screenMargin)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { AmbientBackground() }
        // Stock system back button only — no custom back button.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCountryPicker) {
            CountryPickerView(selection: $country)
                .presentationDetents([.medium])
        }
        .sheet(item: $presentedURL) { presented in
            SafariView(url: presented.url)
                .ignoresSafeArea()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                fieldFocused = true
            }
        }
    }

    private var phoneField: some View {
        HStack(spacing: 10) {
            Button {
                showingCountryPicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(country.flag)
                        .font(.rumiBody)
                    Text(country.dialCode)
                        .font(.rumiBody)
                        .foregroundStyle(Color.labelPrimary)
                    Image(systemName: "chevron.down")
                        .font(.rumiCaption2.weight(.medium))
                        .foregroundStyle(Color.labelQuaternary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            Rectangle()
                .fill(Color.separator)
                .frame(width: 0.5, height: 22)

            TextField("555 123 4567", text: $phone)
                .font(.rumiBody)
                .foregroundStyle(Color.labelPrimary)
                .keyboardType(.phonePad)
                .focused($fieldFocused)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color.fillPrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.separator.opacity(0.7), lineWidth: 0.5)
        )
    }
}

// MARK: - Country picker

private struct CountryPickerView: View {
    @Binding var selection: Country
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let countries: [Country] = [
        Country(iso: "US", name: "United States", dialCode: "+1"),
        Country(iso: "CA", name: "Canada", dialCode: "+1"),
        Country(iso: "GB", name: "United Kingdom", dialCode: "+44"),
        Country(iso: "AU", name: "Australia", dialCode: "+61"),
        Country(iso: "NZ", name: "New Zealand", dialCode: "+64"),
        Country(iso: "IE", name: "Ireland", dialCode: "+353"),
        Country(iso: "FR", name: "France", dialCode: "+33"),
        Country(iso: "DE", name: "Germany", dialCode: "+49"),
        Country(iso: "ES", name: "Spain", dialCode: "+34"),
        Country(iso: "IT", name: "Italy", dialCode: "+39"),
        Country(iso: "NL", name: "Netherlands", dialCode: "+31"),
        Country(iso: "BE", name: "Belgium", dialCode: "+32"),
        Country(iso: "CH", name: "Switzerland", dialCode: "+41"),
        Country(iso: "AT", name: "Austria", dialCode: "+43"),
        Country(iso: "SE", name: "Sweden", dialCode: "+46"),
        Country(iso: "NO", name: "Norway", dialCode: "+47"),
        Country(iso: "DK", name: "Denmark", dialCode: "+45"),
        Country(iso: "FI", name: "Finland", dialCode: "+358"),
        Country(iso: "PT", name: "Portugal", dialCode: "+351"),
        Country(iso: "PL", name: "Poland", dialCode: "+48"),
        Country(iso: "GR", name: "Greece", dialCode: "+30"),
        Country(iso: "MX", name: "Mexico", dialCode: "+52"),
        Country(iso: "BR", name: "Brazil", dialCode: "+55"),
        Country(iso: "AR", name: "Argentina", dialCode: "+54"),
        Country(iso: "CL", name: "Chile", dialCode: "+56"),
        Country(iso: "CO", name: "Colombia", dialCode: "+57"),
        Country(iso: "JP", name: "Japan", dialCode: "+81"),
        Country(iso: "KR", name: "South Korea", dialCode: "+82"),
        Country(iso: "CN", name: "China", dialCode: "+86"),
        Country(iso: "IN", name: "India", dialCode: "+91"),
        Country(iso: "ID", name: "Indonesia", dialCode: "+62"),
        Country(iso: "MY", name: "Malaysia", dialCode: "+60"),
        Country(iso: "SG", name: "Singapore", dialCode: "+65"),
        Country(iso: "TH", name: "Thailand", dialCode: "+66"),
        Country(iso: "VN", name: "Vietnam", dialCode: "+84"),
        Country(iso: "PH", name: "Philippines", dialCode: "+63"),
        Country(iso: "AE", name: "United Arab Emirates", dialCode: "+971"),
        Country(iso: "SA", name: "Saudi Arabia", dialCode: "+966"),
        Country(iso: "IL", name: "Israel", dialCode: "+972"),
        Country(iso: "TR", name: "Turkey", dialCode: "+90"),
        Country(iso: "ZA", name: "South Africa", dialCode: "+27"),
        Country(iso: "NG", name: "Nigeria", dialCode: "+234"),
        Country(iso: "KE", name: "Kenya", dialCode: "+254"),
        Country(iso: "EG", name: "Egypt", dialCode: "+20"),
        Country(iso: "MA", name: "Morocco", dialCode: "+212"),
    ]

    private var filtered: [Country] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.dialCode.contains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selection = country
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(country.flag)
                            .font(.rumiTitle3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .font(.rumiBody)
                                .foregroundStyle(Color.labelPrimary)
                            Text(country.dialCode)
                                .font(.rumiFootnote)
                                .foregroundStyle(Color.labelTertiary)
                        }
                        Spacer()
                        if country == selection {
                            Image(systemName: "checkmark")
                                .font(.rumiFootnote.weight(.medium))
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .listRowBackground(Color.fillPrimary)
                .listRowSeparatorTint(Color.separator)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { ScreenBackground() }
            .navigationTitle("Country code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search country or code")
            .font(.rumiBody)
        }
        .tint(.brandPrimary)
    }
}

#Preview {
    PhoneEntryView(
        flow: .newUser,
        phone: .constant(""),
        country: .constant(Country(iso: "US", name: "United States", dialCode: "+1")),
        onContinue: { _ in }
    )
}

#Preview {
    SafariView(url: URL(string: "https://example.com/terms")!)
}
