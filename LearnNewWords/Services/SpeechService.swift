import AVFoundation

/// Speech synthesis wrapper. Replaces Web Speech API used in content.js.
/// Speaks English words aloud when EN→VN quiz questions are displayed.
final class SpeechService: @unchecked Sendable {

    @MainActor static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    /// Serial queue keeps AVSpeechSynthesizer calls off the main thread.
    /// AVSpeechSynthesizer uses XPC to the speech daemon which can block
    /// the main thread long enough to cause a spinning cursor.
    private let queue = DispatchQueue(label: "com.learnNewWords.speech", qos: .userInitiated)

    private init() {}

    // MARK: - Public API

    /// Speaks `text` in the given BCP-47 language tag (default: American English).
    /// Stops any in-progress speech before starting. Runs off the main thread.
    func speak(_ text: String, language: String = "en-US") {
        queue.async { [weak self] in
            guard let self else { return }
            self.synthesizer.stopSpeaking(at: .immediate)

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice  = AVSpeechSynthesisVoice(language: language)
            utterance.rate   = 0.45   // slightly slower than default for clarity
            utterance.volume = 0.9

            self.synthesizer.speak(utterance)
        }
    }

    /// Immediately stops any ongoing speech.
    func stop() {
        queue.async { [weak self] in
            self?.synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
