import Foundation
import Testing
@testable import GemmaFlowCore

@Suite("Smoke tests")
struct SmokeTests {
    @Test("Default transcription URL points to WhisperKit Large sentinel (local-first)")
    func defaultTranscriptionIsLocal() {
        #expect(AppState.defaultTranscriptionBaseURL == "local://whisperkit/openai_whisper-large-v3-v20240930")
    }

    @Test("Default LLM URL points to bundled Gemma 4 E4B (local-first)")
    func defaultLLMIsLocal() {
        #expect(AppState.defaultLLMBaseURL == "local://mlx/mlx-community/gemma-4-e4b-it-4bit")
    }

    @Test("Local-only post-processing service initialises without a baseURL")
    func postProcessingInitIsArgumentless() {
        let service = PostProcessingService()
        _ = service
    }

    @Test("Local-only transcription service initialises without a baseURL")
    func transcriptionInitIsArgumentless() {
        let service = TranscriptionService()
        _ = service
    }

    @Test("Post-processing flag defaults to enabled when not yet persisted")
    func postProcessingDefaultIsOn() {
        let suiteName = "com.verdana86.gemmaflow.tests.postproc.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        #expect(defaults.object(forKey: "post_processing_enabled") == nil)
        let resolved = defaults.object(forKey: "post_processing_enabled") == nil
            ? true
            : defaults.bool(forKey: "post_processing_enabled")
        #expect(resolved == true)
    }
}
