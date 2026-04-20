import Testing
@testable import FreeFlowCore

@Suite("Endpoint resolution — Step 1 split baseURL/apiKey")
struct EndpointResolutionTests {
    @Test("Empty specific value falls back to legacy")
    func emptyFallsBack() {
        #expect(AppState.resolveEndpoint(specific: "", legacy: "https://api.groq.com/openai/v1") == "https://api.groq.com/openai/v1")
    }

    @Test("Whitespace-only specific value falls back to legacy")
    func whitespaceFallsBack() {
        #expect(AppState.resolveEndpoint(specific: "   ", legacy: "https://api.groq.com/openai/v1") == "https://api.groq.com/openai/v1")
        #expect(AppState.resolveEndpoint(specific: "\t\n", legacy: "https://api.groq.com/openai/v1") == "https://api.groq.com/openai/v1")
    }

    @Test("Non-empty specific value wins and is trimmed")
    func specificWins() {
        #expect(AppState.resolveEndpoint(specific: "http://localhost:11434/v1", legacy: "https://api.groq.com/openai/v1") == "http://localhost:11434/v1")
        #expect(AppState.resolveEndpoint(specific: "  http://localhost:11434/v1  ", legacy: "https://api.groq.com/openai/v1") == "http://localhost:11434/v1")
    }

    @Test("Both empty returns empty — caller responsibility to validate")
    func bothEmpty() {
        #expect(AppState.resolveEndpoint(specific: "", legacy: "") == "")
    }

    @Test("Same function resolves API keys identically")
    func worksForAPIKeys() {
        #expect(AppState.resolveEndpoint(specific: "", legacy: "gsk_abc") == "gsk_abc")
        #expect(AppState.resolveEndpoint(specific: "ollama", legacy: "gsk_abc") == "ollama")
    }
}
