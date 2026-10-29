//
//  SafariView.swift
//  Rumi
//

import SafariServices
import SwiftUI

/// Presents a URL in the native SFSafariViewController (standard system browser chrome).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Identifiable wrapper so a URL can drive `.sheet(item:)`.
struct PresentedURL: Identifiable {
    let id = UUID()
    let url: URL
}
