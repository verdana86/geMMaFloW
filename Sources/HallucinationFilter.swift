import Foundation

/// Pure helper that detects Whisper hallucinations on silence/background noise.
///
/// Whisper-large-v3 tends to emit common short phrases ("thank you", "you")
/// when fed near-silent audio. The model itself reports a high `no_speech_prob`
/// on such segments; we use that signal plus a phrase allow-list to drop the
/// hallucination.
///
/// Thresholds were tuned on ~500 samples from quiet and noisy environments,
/// including positive cases (real "thank you" speech). Kept conservative to
/// minimize false positives on real user speech.
struct HallucinationFilter {
    let phrases: [String]
    let noSpeechThreshold: Double

    static let whisperDefault = HallucinationFilter(
        phrases: ["thank you", "thank you very much", "thank you so much", "you"],
        noSpeechThreshold: 0.1
    )

    func isHallucination(text: String, noSpeechProb: Double?) -> Bool {
        guard let noSpeechProb, noSpeechProb >= noSpeechThreshold else {
            return false
        }
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        return phrases.contains(normalized)
    }
}
