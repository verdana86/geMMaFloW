import Foundation
import Testing
@testable import FreeFlowCore

@Suite("LLMBackend — payload building and response parsing")
struct LLMBackendTests {
    @Test("Payload serializes messages in order with role + content")
    func basicPayload() throws {
        let request = LLMChatRequest(
            model: "gemma3n:e4b",
            messages: [
                LLMChatMessage(role: .system, content: "You are helpful."),
                LLMChatMessage(role: .user, content: "Ciao")
            ],
            temperature: 0.0
        )
        let payload = RemoteOpenAILLMBackend.buildPayload(from: request)

        #expect(payload["model"] as? String == "gemma3n:e4b")
        #expect(payload["temperature"] as? Double == 0.0)
        let messages = try #require(payload["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0] == ["role": "system", "content": "You are helpful."])
        #expect(messages[1] == ["role": "user", "content": "Ciao"])
    }

    @Test("Optional reasoning fields are omitted when not provided")
    func reasoningFieldsOmittedByDefault() {
        let request = LLMChatRequest(
            model: "gemma3n:e4b",
            messages: [],
            temperature: 0.0
        )
        let payload = RemoteOpenAILLMBackend.buildPayload(from: request)
        #expect(payload["reasoning_effort"] == nil)
        #expect(payload["include_reasoning"] == nil)
        #expect(payload["max_completion_tokens"] == nil)
    }

    @Test("Reasoning + max_completion_tokens are emitted for gpt-oss-style models")
    func reasoningFieldsEmitted() {
        let request = LLMChatRequest(
            model: "openai/gpt-oss-20b",
            messages: [],
            temperature: 0.0,
            maxCompletionTokens: 2048,
            reasoningEffort: "low",
            includeReasoning: false
        )
        let payload = RemoteOpenAILLMBackend.buildPayload(from: request)
        #expect(payload["max_completion_tokens"] as? Int == 2048)
        #expect(payload["reasoning_effort"] as? String == "low")
        #expect(payload["include_reasoning"] as? Bool == false)
    }

    @Test("Parsing extracts choices[0].message.content")
    func parseValidResponse() throws {
        let json = """
        {"choices":[{"message":{"role":"assistant","content":"Hello there"}}]}
        """.data(using: .utf8)!
        let content = try RemoteOpenAILLMBackend.extractContent(from: json)
        #expect(content == "Hello there")
    }

    @Test("Parsing throws on missing choices")
    func parseMissingChoices() {
        let json = "{}".data(using: .utf8)!
        #expect(throws: LLMBackendError.self) {
            _ = try RemoteOpenAILLMBackend.extractContent(from: json)
        }
    }

    @Test("Parsing throws on empty choices array")
    func parseEmptyChoices() {
        let json = "{\"choices\":[]}".data(using: .utf8)!
        #expect(throws: LLMBackendError.self) {
            _ = try RemoteOpenAILLMBackend.extractContent(from: json)
        }
    }

    @Test("Parsing throws on non-JSON body")
    func parseNonJSON() {
        let data = "not json".data(using: .utf8)!
        #expect(throws: LLMBackendError.self) {
            _ = try RemoteOpenAILLMBackend.extractContent(from: data)
        }
    }
}
