import SwiftUI

/// No local portal credentials or simulated import success. Authorization is a separate service.
struct RecordConnectView: View {
    var onDone: () -> Void
    @State private var showsAvailability: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Your story.\nIn one place.")
                .font(NudgeType.serif(34))
                .foregroundStyle(Theme.brandForest)
            Text("Connect your healthcare providers to bring your records together. Choose what to share, and add more sources whenever you’re ready.")
                .font(NudgeType.rounded(15))
                .foregroundStyle(Theme.inkMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.brandForest)
                    .frame(width: 54, height: 54)
                    .background(Theme.brandMint.opacity(0.18), in: .circle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Labs, medications & visit history")
                        .font(NudgeType.rounded(14, .medium))
                    Text("From the sources you authorize")
                        .font(NudgeType.rounded(12))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.vertical, 12)
            VStack(spacing: 10) {
                Button { showsAvailability = true } label: {
                    Text("Connect my records")
                        .font(NudgeType.rounded(16, .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color(hex: 0x003B30), in: .capsule)
                }
                .buttonStyle(NudgeButtonStyle())
                Button(action: onDone) {
                    Text("Explore the demo for now")
                        .font(NudgeType.rounded(14, .medium))
                        .foregroundStyle(Theme.brandForest)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(NudgeButtonStyle())
            }
            Text("This preview uses sample records. No provider has been connected and no medical history has been imported.")
                .font(NudgeType.rounded(12))
                .foregroundStyle(Theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .alert("Records connection isn’t enabled yet", isPresented: $showsAvailability) {
            Button("Keep exploring", action: onDone)
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Secure provider authorization needs to be configured before you can connect. You can explore sample records without entering any portal credentials.")
        }
    }
}
