import Testing
@testable import FreeFlowCore

@Suite("Smoke tests")
struct SmokeTests {
    @Test("Library links and static constants are accessible")
    func libraryLinks() {
        #expect(AppState.defaultAPIBaseURL == "https://api.groq.com/openai/v1")
    }

    @Test("Default models match upstream Groq values")
    func defaultModelsAreGroqValues() {
        #expect(AppState.defaultTranscriptionModel == "whisper-large-v3")
        #expect(AppState.defaultPostProcessingModel == "openai/gpt-oss-20b")
    }
}
