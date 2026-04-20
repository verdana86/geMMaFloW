import Foundation

/// Abstraction over the different ways we can ask a language model to run a
/// chat completion. Today only the remote OpenAI-compatible backend exists;
/// Step 3b will add a local in-process backend (llama.cpp or MLX Swift) that
/// conforms to the same protocol so `PostProcessingService` and
/// `AppContextService` don't need to know which runtime answers.
protocol LLMBackend {
    func complete(_ request: LLMChatRequest) async throws -> String
}

struct LLMChatMessage: Equatable {
    enum Role: String, Equatable {
        case system, user, assistant
    }

    let role: Role
    let content: String
}

struct LLMChatRequest {
    let model: String
    let messages: [LLMChatMessage]
    let temperature: Double
    /// Only sent to the wire when non-nil. Groq's `openai/gpt-oss-20b`
    /// requires this; Gemma models must NOT receive it.
    let maxCompletionTokens: Int?
    let reasoningEffort: String?
    let includeReasoning: Bool?
    let timeoutSeconds: TimeInterval

    init(
        model: String,
        messages: [LLMChatMessage],
        temperature: Double = 0.0,
        maxCompletionTokens: Int? = nil,
        reasoningEffort: String? = nil,
        includeReasoning: Bool? = nil,
        timeoutSeconds: TimeInterval = 30
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxCompletionTokens = maxCompletionTokens
        self.reasoningEffort = reasoningEffort
        self.includeReasoning = includeReasoning
        self.timeoutSeconds = timeoutSeconds
    }
}

enum LLMBackendError: LocalizedError {
    case requestFailed(Int, String)
    case invalidResponse(String)
    case emptyOutput
    case requestTimedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode, let details):
            "LLM request failed with status \(statusCode): \(details)"
        case .invalidResponse(let details):
            "Invalid LLM response: \(details)"
        case .emptyOutput:
            "LLM returned empty output"
        case .requestTimedOut(let seconds):
            "LLM request timed out after \(Int(seconds))s"
        }
    }
}
