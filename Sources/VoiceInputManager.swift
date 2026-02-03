import Foundation
import Speech
import AVFoundation

/// Manages voice input using macOS Speech Recognition
class VoiceInputManager: NSObject, ObservableObject {
    static let shared = VoiceInputManager()

    // Track if this manager was ever actually used
    private(set) var wasUsed: Bool = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var currentLanguageCode: String = "en-US"
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private lazy var audioEngine = AVAudioEngine()  // Lazy to avoid triggering mic permission on init

    @Published var isListening: Bool = false
    @Published var currentTranscript: String = ""
    @Published var isAuthorized: Bool = false

    // Callbacks
    var onTranscriptUpdate: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onLog: ((String) -> Void)?

    // Helper to log to both NSLog (stdout) and UI
    private func log(_ message: String) {
        let formattedMessage = "[Voice] \(message)"
        NSLog(formattedMessage)
        onLog?(formattedMessage)
    }

    private override init() {
        super.init()
        // Load saved language preference
        currentLanguageCode = InputSettings.shared.voiceLanguage
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguageCode))

        // Check the authorization status at initialization.
        // This does NOT trigger a user prompt - it just reads the current state.
        isAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Language Selection

    func setLanguage(_ languageCode: String) {
        guard languageCode != currentLanguageCode else { return }

        // Stop any ongoing recognition
        if isListening {
            stopListening()
        }

        // Update language
        currentLanguageCode = languageCode
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))

        log("Language changed to: \(languageCode)")
    }

    // MARK: - Authorization

    func checkAuthorization() {
        wasUsed = true  // Mark as used

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    self?.log("Speech recognition authorized")
                case .denied:
                    self?.isAuthorized = false
                    self?.onError?("Speech recognition denied")
                case .restricted:
                    self?.isAuthorized = false
                    self?.onError?("Speech recognition restricted")
                case .notDetermined:
                    self?.isAuthorized = false
                    self?.log("Speech recognition not yet determined")
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }

    /// Check if BOTH microphone and speech recognition are authorized
    static func checkVoiceInputPermissions() -> Bool {
        let hasMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let hasSpeech = SFSpeechRecognizer.authorizationStatus() == .authorized
        return hasMicrophone && hasSpeech
    }

    /// Request BOTH microphone and speech recognition permissions
    static func requestVoiceInputPermissions(completion: @escaping (Bool) -> Void) {
        // First request microphone
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            guard micGranted else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            // Then request speech recognition
            SFSpeechRecognizer.requestAuthorization { speechStatus in
                DispatchQueue.main.async {
                    completion(speechStatus == .authorized)
                }
            }
        }
    }

    // MARK: - Voice Recognition

    func startListening() {
        wasUsed = true  // Mark as used

        // Only start if already authorized - don't request permission on the fly
        guard isAuthorized else {
            onError?("Speech recognition not authorized. Please grant permission in System Settings.")
            return
        }

        // Already authorized, start listening
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

        // Stop any ongoing recognition (force cancel since we're starting fresh)
        forceStopListening()

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

            // Log EVERY callback invocation
            DispatchQueue.main.async {
                self.log("[CALLBACK] result=\(result != nil) error=\(error != nil) isListening=\(self.isListening)")
            }

            var shouldFinalize = false
            var finalTranscript: String?

            if let result = result {
                let transcript = result.bestTranscription.formattedString
                let segmentCount = result.bestTranscription.segments.count

                DispatchQueue.main.async {
                    self.log("[DEBUG] segments:\(segmentCount) isFinal:\(result.isFinal) transcript:\"\(transcript)\"")
                    self.currentTranscript = transcript
                    self.onTranscriptUpdate?(transcript)
                }

                if result.isFinal {
                    shouldFinalize = true
                    finalTranscript = transcript
                }
            }

            if let error = error {
                shouldFinalize = true
                finalTranscript = self.currentTranscript // Use last known transcript on error
                DispatchQueue.main.async {
                    self.log("[ERROR] \(error.localizedDescription)")
                }
            }

            // When final result or error, stop audio and deliver final transcript
            if shouldFinalize {
                self.stopAudioEngine()
                DispatchQueue.main.async {
                    if let transcript = finalTranscript, !transcript.isEmpty {
                        self.log("Final: \(transcript)")
                        self.onFinalTranscript?(transcript)
                    }
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
            log("Listening...")
        } catch {
            onError?("Audio engine failed: \(error.localizedDescription)")
            stopListening()
        }
    }

    /// Stop the audio engine and clean up resources
    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            log("Audio engine stopped")
        }
        isListening = false
    }

    func stopListening() {
        log("[STOP] Called - isListening=\(isListening) transcript=\"\(currentTranscript)\"")

        // Signal to the recognizer that no more audio is coming
        // The final result will be delivered via the recognitionTask callback
        if isListening {
            log("[STOP] Calling endAudio()...")
            recognitionRequest?.endAudio()
            log("[STOP] endAudio() called - waiting for final callback...")
            // Don't stop audio engine here - let the callback handle it when final result arrives
        }
    }

    /// Force stop and transition - used when starting a new recognition session
    private func forceStopListening() {
        log("[FORCE_STOP] Starting - isListening=\(isListening) transcript=\"\(currentTranscript)\"")

        // Stop audio engine cleanly
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            log("[FORCE_STOP] Audio engine stopped")
        }

        // Cancel the recognition task - don't wait for callback
        recognitionTask?.cancel()
        recognitionTask = nil

        // Clean up request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // DON'T type here - the previous stopListening() callback will handle typing
        // when its final result arrives. This prevents double-typing.
        log("[FORCE_STOP] Cancelled - previous session will finalize via callback")

        isListening = false
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
        onLog?("[Keyboard] Typed: \(currentTranscript)")
        currentTranscript = ""
    }
}
