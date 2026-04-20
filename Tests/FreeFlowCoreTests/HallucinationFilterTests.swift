import Testing
@testable import FreeFlowCore

@Suite("Hallucination filter — Whisper short-phrase silence detection")
struct HallucinationFilterTests {
    let filter = HallucinationFilter.whisperDefault

    @Test("Known phrase with high no_speech_prob is flagged")
    func highNoSpeechIsHallucination() {
        #expect(filter.isHallucination(text: "thank you", noSpeechProb: 0.5) == true)
        #expect(filter.isHallucination(text: "Thank you.", noSpeechProb: 0.2) == true)
        #expect(filter.isHallucination(text: "you", noSpeechProb: 0.15) == true)
    }

    @Test("Known phrase with low no_speech_prob is real speech, not flagged")
    func lowNoSpeechIsRealSpeech() {
        #expect(filter.isHallucination(text: "thank you", noSpeechProb: 0.05) == false)
        #expect(filter.isHallucination(text: "you", noSpeechProb: 0.0) == false)
    }

    @Test("Unknown phrase is never flagged regardless of probability")
    func unknownPhraseNeverFlagged() {
        #expect(filter.isHallucination(text: "ciao mondo", noSpeechProb: 0.99) == false)
        #expect(filter.isHallucination(text: "Buongiorno", noSpeechProb: 0.5) == false)
    }

    @Test("Nil no_speech_prob means 'cannot determine' and does not flag")
    func nilProbabilityDoesNotFlag() {
        #expect(filter.isHallucination(text: "thank you", noSpeechProb: nil) == false)
    }

    @Test("Normalization strips punctuation and case")
    func normalizationIsRobust() {
        #expect(filter.isHallucination(text: "  Thank you!  ", noSpeechProb: 0.5) == true)
        #expect(filter.isHallucination(text: "THANK YOU.", noSpeechProb: 0.5) == true)
    }
}
