import Foundation
import Testing
@testable import GemmaFlowCore

@Suite("LLMBackendKind — routing by URL sentinel")
struct LLMBackendKindTests {
    @Test("HTTPS URL routes to remote")
    func httpsRemote() throws {
        let kind = try LLMBackendKind.parse(baseURL: "https://api.groq.com/openai/v1")
        #expect(kind == .remoteOpenAI("https://api.groq.com/openai/v1"))
    }

    @Test("HTTP URL (local Ollama) also routes remote")
    func httpRemote() throws {
        let kind = try LLMBackendKind.parse(baseURL: "http://localhost:11434/v1")
        #expect(kind == .remoteOpenAI("http://localhost:11434/v1"))
    }

    @Test("Whitespace trimmed")
    func trimmed() throws {
        let kind = try LLMBackendKind.parse(baseURL: "  https://api.groq.com/openai/v1  ")
        #expect(kind == .remoteOpenAI("https://api.groq.com/openai/v1"))
    }

    @Test("local://mlx → bundled MLX with default model")
    func bareMLXSentinel() throws {
        let kind = try LLMBackendKind.parse(baseURL: "local://mlx")
        #expect(kind == .localMLX(modelId: nil))
    }

    @Test("local://mlx/<repo>/<model> carries the full HF repo id as modelId")
    func mlxWithVariant() throws {
        let kind = try LLMBackendKind.parse(baseURL: "local://mlx/mlx-community/gemma-4-e4b-it-4bit")
        #expect(kind == .localMLX(modelId: "mlx-community/gemma-4-e4b-it-4bit"))
    }

    @Test("Empty URL throws")
    func emptyThrows() {
        #expect(throws: LLMBackendError.self) {
            try LLMBackendKind.parse(baseURL: "")
        }
    }

    @Test("Unsupported scheme throws")
    func unsupportedScheme() {
        #expect(throws: LLMBackendError.self) {
            try LLMBackendKind.parse(baseURL: "ftp://example.com")
        }
    }

    @Test("local://unknown-runtime throws (only mlx supported today)")
    func unknownLocalRuntime() {
        #expect(throws: LLMBackendError.self) {
            try LLMBackendKind.parse(baseURL: "local://llama-cpp/some-model")
        }
    }
}

@Suite("LocalLLMModelChoice — curated bundled LLM presets")
struct LocalLLMModelChoiceTests {
    @Test("Default is Gemma 4 E4B 4-bit (~3.8GB on disk)")
    func defaultIsE4B() {
        #expect(LocalLLMModelChoice.default == .gemma4E4B4bit)
    }

    @Test("Each preset encodes the right HuggingFace repo id")
    func modelIdsMatchMLXRegistry() {
        #expect(LocalLLMModelChoice.gemma4E4B4bit.mlxModelId == "mlx-community/gemma-4-e4b-it-4bit")
        #expect(LocalLLMModelChoice.gemma4E2B4bit.mlxModelId == "mlx-community/gemma-4-e2b-it-4bit")
    }

    @Test("Sentinel URL encodes the model id in the path")
    func sentinel() {
        #expect(LocalLLMModelChoice.gemma4E4B4bit.sentinelBaseURL == "local://mlx/mlx-community/gemma-4-e4b-it-4bit")
    }

    @Test("Round-trip: sentinel → choice → sentinel")
    func roundTrip() {
        for choice in LocalLLMModelChoice.allCases {
            #expect(LocalLLMModelChoice.fromSentinelBaseURL(choice.sentinelBaseURL) == choice)
        }
    }

    @Test("Bare local://mlx migrates to default")
    func bareMLXMigrates() {
        #expect(LocalLLMModelChoice.fromSentinelBaseURL("local://mlx") == .default)
    }

    @Test("Unknown repo returns nil (free-form custom)")
    func unknownRepoReturnsNil() {
        #expect(LocalLLMModelChoice.fromSentinelBaseURL("local://mlx/mlx-community/my-custom-model") == nil)
    }

    @Test("Remote URL returns nil")
    func remoteReturnsNil() {
        #expect(LocalLLMModelChoice.fromSentinelBaseURL("https://api.groq.com/openai/v1") == nil)
    }
}
