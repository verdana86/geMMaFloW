import Testing
@testable import GemmaFlowCore

@Suite("WhisperKitModelChoice — UI preset ↔ sentinel URL round-trip")
struct WhisperKitModelChoiceTests {
    @Test("Default is Large (full precision, same as WhisperKit auto on M2+)")
    func defaultIsLarge() {
        #expect(WhisperKitModelChoice.default == .large)
    }

    @Test("Legacy Turbo sentinel URL falls back to the default (Large)")
    func legacyTurboURLMapsToDefault() {
        // Turbo was removed from the picker because it hangs in
        // MLE5Engine.loadModel. Old installs with a Turbo-scoped URL in
        // UserDefaults must resolve to Large rather than return nil.
        #expect(WhisperKitModelChoice.fromSentinelBaseURL("local://whisperkit/openai_whisper-large-v3-v20240930_turbo_632MB") == nil)
    }

    @Test("Large sentinel encodes the full 1.5GB identifier")
    func largeSentinel() {
        #expect(WhisperKitModelChoice.large.sentinelBaseURL == "local://whisperkit/openai_whisper-large-v3-v20240930")
    }

    @Test("Small sentinel encodes the 220MB quantized identifier")
    func smallSentinel() {
        #expect(WhisperKitModelChoice.small.sentinelBaseURL == "local://whisperkit/openai_whisper-small_216MB")
    }

    @Test("Round-trip: sentinel → choice → sentinel preserves every preset")
    func roundTrip() {
        for choice in WhisperKitModelChoice.allCases {
            let url = choice.sentinelBaseURL
            #expect(WhisperKitModelChoice.fromSentinelBaseURL(url) == choice)
        }
    }

    @Test("Bare local://whisperkit (no variant) migrates to default (.large)")
    func bareURLMigratesToLarge() {
        #expect(WhisperKitModelChoice.fromSentinelBaseURL("local://whisperkit") == .large)
    }

    @Test("Unknown custom variant returns nil (not a preset — free-form editing)")
    func unknownVariantReturnsNil() {
        #expect(WhisperKitModelChoice.fromSentinelBaseURL("local://whisperkit/my-custom-model") == nil)
    }

    @Test("Non-WhisperKit URL returns nil")
    func nonWhisperKitURLReturnsNil() {
        #expect(WhisperKitModelChoice.fromSentinelBaseURL("https://api.groq.com/openai/v1") == nil)
        #expect(WhisperKitModelChoice.fromSentinelBaseURL("local://other-runtime") == nil)
    }

    @Test("Empty URL returns nil")
    func emptyURLReturnsNil() {
        #expect(WhisperKitModelChoice.fromSentinelBaseURL("") == nil)
    }

    @Test("allCases has Large and Small only — Turbo is hidden due to load hang")
    func exactlyTwoPresets() {
        #expect(WhisperKitModelChoice.allCases.count == 2)
        #expect(Set(WhisperKitModelChoice.allCases) == Set([.large, .small]))
    }
}
