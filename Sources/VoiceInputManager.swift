import Foundation
import Speech
import AVFoundation

/// Manages voice input using macOS Speech Recognition
class VoiceInputManager: NSObject, ObservableObject {
    static let shared = VoiceInputManager()

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var isListening: Bool = false
    @Published var currentTranscript: String = ""
    @Published var isAuthorized: Bool = false

    // Callbacks
    var onTranscriptUpdate: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onLog: ((String) -> Void)?

    private override init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        // Don't request authorization at init - wait until user activates voice mode
    }

    // MARK: - Authorization

    func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    self?.onLog?("🎤 Speech recognition authorized")
                case .denied:
                    self?.isAuthorized = false
                    self?.onError?("Speech recognition denied")
                case .restricted:
                    self?.isAuthorized = false
                    self?.onError?("Speech recognition restricted")
                case .notDetermined:
                    self?.isAuthorized = false
                    self?.onLog?("Speech recognition not yet determined")
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }

    static func checkMicrophonePermission() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        default:
            return false
        }
    }

    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Voice Recognition

    func startListening() {
        // Request authorization if not already authorized
        if !isAuthorized {
            checkAuthorization()
            // Wait a moment for authorization, then try to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startListeningIfAuthorized()
            }
            return
        }

        startListeningIfAuthorized()
    }

    private func startListeningIfAuthorized() {
        guard isAuthorized else {
            onError?("Speech recognition not authorized")
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            onError?("Speech recognizer not available")
            return
        }

        // Stop any ongoing recognition
        stopListening()

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            onError?("Failed to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // On-device recognition if available (faster, more private)
        if #available(macOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.currentTranscript = transcript
                    self.onTranscriptUpdate?(transcript)

                    if result.isFinal {
                        self.onFinalTranscript?(transcript)
                        self.onLog?("🎤 Final: \(transcript)")
                    }
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.onError?("Recognition error: \(error.localizedDescription)")
                    self.stopListening()
                }
            }
        }

        // Configure audio
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            currentTranscript = ""
            onLog?("🎤 Listening...")
        } catch {
            onError?("Audio engine failed: \(error.localizedDescription)")
            stopListening()
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        let wasListening = isListening
        isListening = false

        if wasListening {
            onLog?("🎤 Stopped listening")
        }
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    // MARK: - Type Transcript

    /// Type the current transcript as text input
    func typeCurrentTranscript() {
        guard !currentTranscript.isEmpty else { return }
        InputController.shared.typeText(currentTranscript)
        onLog?("⌨️ Typed: \(currentTranscript)")
        currentTranscript = ""
    }
}
