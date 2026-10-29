import SwiftUI

/// An exact-proposal review with decision controls outside the scrolling details.
struct ApprovalReviewView: View {
    let proposal: String
    let disclosure: String
    let approve: () -> Void
    let decline: () -> Void
    var changeProposal: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Before I continue", systemImage: "hand.raised")
                        .font(NudgeType.serif(26))
                    Text(proposal).font(NudgeType.rounded(16)).textSelection(.enabled)
                    Text(disclosure).font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
                    Text("Your approval applies only to this exact proposal. Changed details require a new review.")
                        .font(NudgeType.rounded(13)).foregroundStyle(Theme.inkMuted)
                    if let changeProposal {
                        Button("Preview a changed fare", action: changeProposal).frame(minHeight: 44)
                    }
                }.padding(20).foregroundStyle(Theme.ink)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button("Approve") { approve(); dismiss() }
                            .buttonStyle(.borderedProminent).tint(Theme.brandForest)
                            .frame(maxWidth: .infinity, minHeight: 48)
                        Button("Decline") { decline(); dismiss() }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity, minHeight: 48)
                    }
                    Button("Review later · keep paused") { dismiss() }.frame(minHeight: 44)
                }.font(NudgeType.rounded(15, .semibold)).padding(16).background(.regularMaterial)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
