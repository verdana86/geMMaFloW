import Testing
@testable import FreeFlowCore

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

    @Test("Legacy defaultAPIBaseURL now mirrors transcription default (local, not Groq)")
    func legacyAPIBaseURLIsLocal() {
        #expect(AppState.defaultAPIBaseURL == AppState.defaultTranscriptionBaseURL)
        #expect(!AppState.defaultAPIBaseURL.hasPrefix("https://"))
    }

    @Test("Default models match upstream Groq values")
    func defaultModelsAreGroqValues() {
        #expect(AppState.defaultTranscriptionModel == "whisper-large-v3")
        #expect(AppState.defaultPostProcessingModel == "openai/gpt-oss-20b")
    }
}
