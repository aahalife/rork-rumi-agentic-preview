//
//  CameraCaptureView.swift
//  Rumi
//
//  Full-screen camera for attaching a photo to a chat message.
//  Real AVFoundation pipeline: preview + AVCapturePhotoOutput.
//

import AVFoundation
import SwiftUI

// MARK: - Session (runs off the main thread)

nonisolated final class CameraSession: @unchecked Sendable {
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "rumi.camera.session")

    /// Prefers the built-in camera; the cloud simulator falls through to its injected external camera.
    static func bestCamera() -> AVCaptureDevice? {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        types.append(.external)
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        ).devices.first
    }

    func configureAndStart(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            if session.inputs.isEmpty {
                session.beginConfiguration()
                if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
                guard let camera = Self.bestCamera(),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      session.canAddInput(input) else {
                    session.commitConfiguration()
                    completion(false)
                    return
                }
                session.addInput(input)
                if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
                session.commitConfiguration()
            }
            if !session.isRunning { session.startRunning() }
            completion(true)
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }
}

// MARK: - Photo capture delegate

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private var completion: ((Data?) -> Void)?

    func capture(with output: AVCapturePhotoOutput, completion: @escaping (Data?) -> Void) {
        guard self.completion == nil else { return }
        // capturePhoto raises without an active video connection.
        guard let connection = output.connection(with: .video), connection.isEnabled, connection.isActive else {
            completion(nil)
            return
        }
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        if output.supportedFlashModes.contains(.auto) { settings.flashMode = .auto }
        output.capturePhoto(with: settings, delegate: self)
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        Task { @MainActor in
            let completion = self.completion
            self.completion = nil
            completion?(data)
        }
    }
}

// MARK: - Model

@Observable
final class CameraModel {
    enum State { case requesting, denied, unavailable, running }

    var state: State = .requesting
    var captured: UIImage?
    var isCapturing = false

    let camera = CameraSession()
    private let delegate = PhotoCaptureDelegate()

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        default:
            state = .denied
            return
        }

        let started = await withCheckedContinuation { continuation in
            camera.configureAndStart { continuation.resume(returning: $0) }
        }
        state = started ? .running : .unavailable
    }

    func stop() { camera.stop() }

    func takePhoto() {
        guard !isCapturing else { return }
        isCapturing = true
        delegate.capture(with: camera.photoOutput) { [weak self] data in
            guard let self else { return }
            self.isCapturing = false
            if let data, let image = UIImage(data: data) {
                withAnimation(.easeOut(duration: 0.2)) { self.captured = image }
            }
        }
    }
}

// MARK: - Preview layer

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Screen

struct CameraCaptureView: View {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = CameraModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                content
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task { await model.start() }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .requesting:
            ProgressView().tint(.white)
        case .denied:
            ContentUnavailableView {
                Label("Camera access is off", systemImage: "camera")
            } description: {
                Text("To take a photo for Rumi, allow camera access in Settings.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glassProminent)
                .tint(.brandPrimary)
            }
            .foregroundStyle(.white)
        case .unavailable:
            ContentUnavailableView(
                "Camera unavailable",
                systemImage: "camera.badge.ellipsis",
                description: Text("No camera was found on this device.")
            )
            .foregroundStyle(.white)
        case .running:
            if let captured = model.captured {
                review(captured)
            } else {
                viewfinder
            }
        }
    }

    private var viewfinder: some View {
        VStack(spacing: 0) {
            CameraPreview(session: model.camera.session)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 8)

            Button {
                model.takePhoto()
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                    Circle().fill(.white).frame(width: 62, height: 62)
                        .scaleEffect(model.isCapturing ? 0.85 : 1)
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: model.isCapturing)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: model.isCapturing) { _, new in new }
            .accessibilityLabel("Take photo")
            .padding(.vertical, 24)
        }
    }

    private func review(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { model.captured = nil }
                } label: {
                    Text("Retake").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                Button {
                    onCapture(image)
                    dismiss()
                } label: {
                    Text("Use photo").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.brandPrimary)
                .controlSize(.large)
            }
            .padding(.horizontal, .screenMargin)
            .padding(.vertical, 24)
        }
    }
}
