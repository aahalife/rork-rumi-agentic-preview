import SwiftUI
import AVFoundation

private final class VoiceMicrophoneGate: @unchecked Sendable {
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var muted = true
    nonisolated(unsafe) private var epoch = 0
    nonisolated init() { }
    nonisolated func setMuted(_ value: Bool) { lock.lock(); defer { lock.unlock() }; muted = value; epoch += 1 }
    nonisolated func stamp() -> Int? { lock.lock(); defer { lock.unlock() }; return muted ? nil : epoch }
    nonisolated func accepts(_ value: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return !muted && epoch == value }
}

@MainActor @Observable
final class RumiVoiceSession {
    enum State: String { case idle = "Ready to talk", connecting = "Connecting…", listening = "Listening", speaking = "Rumi is speaking", denied = "Microphone access is off", ended = "Conversation ended", failed = "Couldn’t connect" }
    private(set) var state: State = .idle
    private(set) var caption = ""
    private(set) var error: String?
    var muted = false { didSet { microphoneGate.setMuted(muted) } }
    @ObservationIgnored private let microphoneGate = VoiceMicrophoneGate()
    @ObservationIgnored private var sendingChunks = 0
    @ObservationIgnored private var socket: URLSessionWebSocketTask?
    @ObservationIgnored private var receiver: Task<Void, Never>?
    @ObservationIgnored private var starter: Task<Void, Never>?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player: AVAudioPlayerNode?
    @ObservationIgnored private var outputFormat: AVAudioFormat?
    @ObservationIgnored private var tapped = false
    @ObservationIgnored private var queuedFrames = 0
    @ObservationIgnored private var generation = UUID()
    struct Ticket: Decodable { let signedURL: String; let userID: String; let proxied: Bool? }
    func start() {
        stop(); state = .connecting; error = nil; caption = ""; muted = false
        let token = generation
        starter = Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard !Task.isCancelled, generation == token else { return }
            guard granted else { state = .denied; return }
            do {
                let ticket: Ticket = try await CompanionConnection.shared.request("voice/session", body: [:])
                guard !Task.isCancelled, generation == token else { return }
                let webSocket: URLSessionWebSocketTask
                if ticket.proxied == true {
                    webSocket = URLSession.shared.webSocketTask(with: try CompanionConnection.shared.voiceRequest(address: ticket.signedURL))
                } else {
                    guard let url = URL(string: ticket.signedURL), url.scheme == "wss", let host = url.host, host == "api.elevenlabs.io" || host.hasSuffix(".elevenlabs.io") else { throw CompanionError(message: "The voice service returned an invalid session address.") }
                    webSocket = URLSession.shared.webSocketTask(with: url)
                }
                socket = webSocket; webSocket.resume()
                try await send(["type": "conversation_initiation_client_data", "user_id": ticket.userID])
                receiver = Task {
                    do {
                        while !Task.isCancelled, generation == token {
                            let incoming = try await webSocket.receive()
                            guard generation == token else { return }
                            let data: Data
                            switch incoming { case .data(let value): data = value; case .string(let value): data = Data(value.utf8); @unknown default: continue }
                            guard let event = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                            try await handle(event, token: token)
                        }
                    } catch {
                        guard generation == token, !Task.isCancelled else { return }
                        fail("The voice connection ended. Tap reconnect to start a new conversation.")
                    }
                }
                // No fake listening state: metadata must arrive and the audio engine must start.
                try await Task.sleep(for: .seconds(20))
                if generation == token, state == .connecting { fail("The voice agent did not become ready. Check the agent’s audio settings.") }
            } catch {
                guard generation == token, !Task.isCancelled else { return }
                fail(error.localizedDescription)
            }
        }
    }
    private func send(_ value: [String: Any]) async throws {
        guard let socket else { throw CompanionError(message: "Voice is not connected.") }
        let data = try JSONSerialization.data(withJSONObject: value)
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }
    private func handle(_ event: [String: Any], token: UUID) async throws {
        switch event["type"] as? String {
        case "conversation_initiation_metadata":
            guard let meta = event["conversation_initiation_metadata_event"] as? [String: Any], let input = meta["user_input_audio_format"] as? String, let output = meta["agent_output_audio_format"] as? String,
                  input.hasPrefix("pcm_"), output.hasPrefix("pcm_"), let inputRate = Double(input.dropFirst(4)), let outputRate = Double(output.dropFirst(4)), (8000...48000).contains(inputRate), (8000...48000).contains(outputRate) else { throw CompanionError(message: "Set this ElevenLabs agent’s input and output to PCM audio, then reconnect.") }
            try configureAudio(inputRate: inputRate, outputRate: outputRate, token: token)
            state = .listening
        case "ping":
            if let ping = event["ping_event"] as? [String: Any], let id = ping["event_id"] { try await send(["type": "pong", "event_id": id]) }
        case "user_transcript":
            if let value = event["user_transcription_event"] as? [String: Any], let text = value["user_transcript"] as? String { caption = text }
        case "agent_response":
            if let value = event["agent_response_event"] as? [String: Any], let text = value["agent_response"] as? String { caption = text }
        case "agent_response_correction":
            if let value = event["agent_response_correction_event"] as? [String: Any], let text = value["corrected_agent_response"] as? String { caption = text }
        case "audio":
            if let value = event["audio_event"] as? [String: Any], let base64 = value["audio_base_64"] as? String, let data = Data(base64Encoded: base64) { try play(data, token: token) }
        case "interruption": player?.stop(); queuedFrames = 0; state = .listening
        case "client_tool_call":
            if let call = event["client_tool_call"] as? [String: Any], let id = call["tool_call_id"] as? String {
                try await send(["type": "client_tool_result", "tool_call_id": id, "result": "Use the Rumi Works screen for browser tasks and native approvals. Voice cannot authorize external actions.", "is_error": true])
            }
        default: break
        }
    }
    private func configureAudio(inputRate: Double, outputRate: Double, token: UUID) throws {
        guard engine == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        self.engine = engine; self.player = player
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: outputRate, channels: 1, interleaved: false),
              let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: inputRate, channels: 1, interleaved: false) else { throw CompanionError(message: "This audio format isn’t supported.") }
        outputFormat = format; engine.attach(player); engine.connect(player, to: engine.mainMixerNode, format: format)
        let input = engine.inputNode, source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0, let converter = AVAudioConverter(from: source, to: target) else { throw CompanionError(message: "No microphone is available. Check your audio device and try again.") }
        let gate = microphoneGate
        input.installTap(onBus: 0, bufferSize: 2048, format: source) { [weak self] buffer, _ in
            guard let stamp = gate.stamp(), let bytes = Self.convert(buffer, converter: converter, format: target) else { return }
            Task { @MainActor [weak self] in
                guard let self, self.generation == token, gate.accepts(stamp), !self.muted else { return }
                guard self.sendingChunks < 5 else { self.fail("The voice connection is too slow. Reconnect when your connection improves."); return }
                self.sendingChunks += 1
                do { try await self.send(["user_audio_chunk": bytes.base64EncodedString()]) }
                catch { if self.generation == token { self.fail("Microphone audio could not be sent. Reconnect to try again.") } }
                if self.generation == token { self.sendingChunks = max(0, self.sendingChunks - 1) }
            }
        }
        tapped = true; engine.prepare(); try engine.start()
    }
    nonisolated private static func convert(_ source: AVAudioPCMBuffer, converter: AVAudioConverter, format: AVAudioFormat) -> Data? {
        let capacity = AVAudioFrameCount(Double(source.frameLength) * format.sampleRate / source.format.sampleRate) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false; var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true; status.pointee = .haveData; return source
        }
        guard error == nil, output.frameLength > 0, let samples = output.int16ChannelData?[0] else { return nil }
        return Data(bytes: samples, count: Int(output.frameLength) * 2)
    }
    private func play(_ data: Data, token: UUID) throws {
        guard data.count % 2 == 0, data.count < 1000000, let format = outputFormat, let player,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count / 2)), let channel = buffer.floatChannelData?[0] else { return }
        let frames = data.count / 2
        guard queuedFrames + frames < Int(format.sampleRate * 20) else { throw CompanionError(message: "Audio playback fell behind. Please reconnect.") }
        buffer.frameLength = AVAudioFrameCount(frames)
        for index in 0..<frames {
            let bits = UInt16(data[index * 2]) | UInt16(data[index * 2 + 1]) << 8
            channel[index] = Float(Int16(bitPattern: bits)) / 32768
        }
        queuedFrames += frames; state = .speaking
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.queuedFrames = max(0, self.queuedFrames - frames)
                if self.queuedFrames == 0 { self.state = .listening }
            }
        }
        if !player.isPlaying { player.play() }
    }
    private func fail(_ text: String) { stop(); state = .failed; error = text }
    func stop() {
        microphoneGate.setMuted(true); sendingChunks = 0
        generation = UUID(); starter?.cancel(); starter = nil; receiver?.cancel(); receiver = nil
        socket?.cancel(with: .normalClosure, reason: nil); socket = nil
        if tapped { engine?.inputNode.removeTap(onBus: 0); tapped = false }
        player?.stop(); engine?.stop(); engine = nil; player = nil; outputFormat = nil; queuedFrames = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if state != .idle { state = .ended }
    }
}

struct VoiceModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var voice = RumiVoiceSession()
    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(Color.brandSecondaryTint).frame(width: 224, height: 224)
                    Circle().fill(Color.brandPrimary.opacity(0.12)).frame(width: voice.state == .speaking ? 190 : 160, height: voice.state == .speaking ? 190 : 160)
                    Image(systemName: voice.state == .denied ? "mic.slash" : "waveform").font(.system(size: 66, weight: .light)).foregroundStyle(Color.brandPrimary)
                }.animation(.smooth(duration: 0.5), value: voice.state)
                Text(voice.muted && voice.state == .listening ? "You’re muted" : voice.state.rawValue).font(.rumiTitle2)
                Text("Live audio is sent to your connected ElevenLabs agent.").font(.rumiCaption1).foregroundStyle(Color.labelSecondary).multilineTextAlignment(.center).padding(.horizontal)
                Text(voice.caption).font(.rumiBody).multilineTextAlignment(.center).frame(minHeight: 100).padding(.horizontal, 24)
                if let error = voice.error { Text(error).font(.rumiFootnote).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal) }
                if voice.state == .denied {
                    Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }.buttonStyle(.borderedProminent)
                }
                if [.failed, .ended].contains(voice.state) { Button("Reconnect") { voice.start() }.buttonStyle(.borderedProminent) }
                Spacer()
                HStack(spacing: 40) {
                    Button { voice.muted.toggle() } label: { Image(systemName: voice.muted ? "mic.slash.fill" : "mic.fill").frame(width: 64, height: 64) }.buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel(voice.muted ? "Unmute" : "Mute").disabled(![.listening, .speaking].contains(voice.state))
                    Button { voice.stop(); dismiss() } label: { Image(systemName: "phone.down.fill").frame(width: 64, height: 64) }.buttonStyle(.glassProminent).buttonBorderShape(.circle).tint(.red).accessibilityLabel("End conversation")
                }.padding(.bottom, 24)
            }.frame(maxWidth: .infinity).background { AmbientBackground() }.navigationTitle("Talk with Rumi").navigationBarTitleDisplayMode(.inline)
        }
        .task { voice.start() }
        .onDisappear { voice.stop() }
        .onChange(of: CompanionConnection.shared.identityVersion) { _, _ in voice.stop(); dismiss() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { voice.stop() } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in voice.stop() }
        .sensoryFeedback(.impact(weight: .light), trigger: voice.state)
    }
}
