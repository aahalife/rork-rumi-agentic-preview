//
//  ChatComposer.swift
//  Rumi
//
//  Growing text input with "+" attachments (Camera, Photos, Files),
//  attachment previews, mic for voice mode, and send / stop.
//

import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ChatComposer: View {
    @Binding var text: String
    @Binding var attachments: [ChatAttachment]
    /// Non-nil while editing a previously sent message.
    let editingMessageID: UUID?
    let isResponding: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onStop: () -> Void
    let onCancelEdit: () -> Void
    let onVoice: () -> Void

    @State private var showingCamera = false
    @State private var showingPhotos = false
    @State private var showingFiles = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var loadingCount = 0

    private var canSend: Bool {
        loadingCount == 0 &&
            (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty)
    }

    var body: some View {
        VStack(spacing: 8) {
            if editingMessageID != nil {
                editBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 10) {
                if editingMessageID == nil {
                    attachMenu
                }

                field

                trailingButton
            }
        }
        .padding(.horizontal, .screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: canSend)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isResponding)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: editingMessageID)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: attachments)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView { image in
                attachments.append(ChatAttachment(
                    kind: .image, thumbnail: image, fileURL: nil, name: "Photo", detail: ""
                ))
            }
        }
        .photosPicker(
            isPresented: $showingPhotos,
            selection: $photoSelection,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            photoSelection = []
            for item in items { load(item) }
        }
        .fileImporter(
            isPresented: $showingFiles,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls { importFile(url) }
        }
    }

    // MARK: Pieces

    private var editBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil")
                .foregroundStyle(Color.brandPrimary)
            Text("Editing message")
                .font(.rumiSubheadline)
                .foregroundStyle(Color.labelSecondary)
            Spacer(minLength: 8)
            Button("Cancel", action: onCancelEdit)
                .buttonStyle(.borderless)
                .tint(.brandPrimary)
                .font(.rumiSubheadline)
        }
        .padding(.horizontal, 4)
    }

    private var attachMenu: some View {
        Menu {
            Button("Camera", systemImage: "camera") { showingCamera = true }
            Button("Photos", systemImage: "photo.on.rectangle") { showingPhotos = true }
            Button("Files", systemImage: "folder") { showingFiles = true }
        } label: {
            Image(systemName: "plus")
                .font(.rumiBody.weight(.medium))
                .foregroundStyle(Color.labelPrimary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel("Add attachment")
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !attachments.isEmpty || loadingCount > 0 {
                attachmentStrip
            }

            TextField("Say anything...", text: $text, axis: .vertical)
                .font(.rumiBody)
                .foregroundStyle(Color.labelPrimary)
                .lineLimit(1...6)
                .focused(isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
        }
        .background(Color.fillPrimary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.separator.opacity(0.7), lineWidth: 0.5)
        )
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPreview(attachment: attachment, size: 64)
                        .overlay(alignment: .topTrailing) {
                            Button {
                                attachments.removeAll { $0.id == attachment.id }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.rumiCaption2.weight(.bold))
                                    .foregroundStyle(Color.labelPrimaryContrast)
                                    .frame(width: 20, height: 20)
                                    .background(Color.fillPrimaryContrast.opacity(0.75), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                            .accessibilityLabel("Remove \(attachment.name)")
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                ForEach(0..<loadingCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.fillSecondary)
                        .frame(width: 64, height: 64)
                        .overlay { ProgressView() }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isResponding && editingMessageID == nil && !canSend {
            circleButton(symbol: "stop.fill", label: "Stop generating", action: onStop)
                .transition(.scale.combined(with: .opacity))
        } else if canSend {
            circleButton(symbol: "arrow.up", label: editingMessageID == nil ? "Send" : "Save edit", action: onSend)
                .transition(.scale.combined(with: .opacity))
        } else {
            circleButton(symbol: "mic.fill", label: "Voice mode", action: onVoice)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func circleButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.rumiBody.weight(.semibold))
                .foregroundStyle(Color.labelPrimaryContrast)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(Color.brandPrimary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .sensoryFeedback(.impact(weight: .light), trigger: symbol)
    }

    // MARK: Loading picked items

    private func load(_ item: PhotosPickerItem) {
        loadingCount += 1
        Task {
            defer { loadingCount -= 1 }
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }),
               let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                let thumbnail = await AttachmentLoader.videoThumbnail(for: movie.url)
                attachments.append(ChatAttachment(
                    kind: .video, thumbnail: thumbnail, fileURL: movie.url, name: "Video", detail: ""
                ))
            } else if let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) {
                attachments.append(ChatAttachment(
                    kind: .image, thumbnail: image, fileURL: nil, name: "Photo", detail: ""
                ))
            }
        }
    }

    private func importFile(_ url: URL) {
        guard let local = AttachmentLoader.copyToTemporary(url) else { return }
        let type = UTType(filenameExtension: local.pathExtension)
        let size = (try? local.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        }
        let typeName = local.pathExtension.isEmpty ? "File" : local.pathExtension.uppercased()
        let detail = [typeName, size].compactMap { $0 }.joined(separator: " · ")

        // Picked images from Files get a real preview.
        if type?.conforms(to: .image) == true, let image = UIImage(contentsOfFile: local.path) {
            attachments.append(ChatAttachment(
                kind: .image, thumbnail: image, fileURL: local, name: local.lastPathComponent, detail: detail
            ))
        } else {
            attachments.append(ChatAttachment(
                kind: .file, thumbnail: nil, fileURL: local, name: local.lastPathComponent, detail: detail
            ))
        }
    }
}

// MARK: - Attachment preview (composer + transcript)

struct AttachmentPreview: View {
    let attachment: ChatAttachment
    var size: CGFloat = 64

    var body: some View {
        switch attachment.kind {
        case .image, .video:
            ZStack {
                if let thumbnail = attachment.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.fillSecondary
                }
                if attachment.kind == .video {
                    Image(systemName: "play.fill")
                        .font(size > 80 ? .rumiTitle3 : .rumiFootnote)
                        .foregroundStyle(.white)
                        .padding(size > 80 ? 12 : 7)
                        .background(.black.opacity(0.45), in: Circle())
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size > 80 ? 16 : 12, style: .continuous))
            .accessibilityLabel(attachment.kind == .video ? "Video" : "Photo")
        case .file:
            HStack(spacing: 10) {
                Image(systemName: attachment.fileSymbol)
                    .font(.rumiTitle3)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.fillTertiary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.name)
                        .font(.rumiSubheadline)
                        .foregroundStyle(Color.labelPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(attachment.detail)
                        .font(.rumiCaption1)
                        .foregroundStyle(Color.labelTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 28)
            .frame(width: 210, height: size, alignment: .leading)
            .background(Color.fillQuaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.separator.opacity(0.6), lineWidth: 0.5)
            )
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Loading helpers

nonisolated struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

enum AttachmentLoader {
    static func videoThumbnail(for url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let result = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: result.image)
    }

    /// Copies a security-scoped file from the Files picker into the app's temporary folder.
    static func copyToTemporary(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
