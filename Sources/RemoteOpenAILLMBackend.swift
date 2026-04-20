import Foundation

/// Chat-completions backend that speaks to an OpenAI-compatible
/// `/chat/completions` endpoint (Groq, Ollama in OpenAI-compat mode,
/// self-hosted gateways). The pure helpers `buildPayload` and
/// `extractContent` live here as static methods so payload shape and
/// response parsing are testable without standing up a mock server.
final class RemoteOpenAILLMBackend: LLMBackend {
    private let apiKey: String
    private let baseURL: String

    init(apiKey: String, baseURL: String) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    func complete(_ request: LLMChatRequest) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMBackendError.invalidResponse("Malformed baseURL: \(baseURL)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = request.timeoutSeconds

        let payload = Self.buildPayload(from: request)
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await LLMAPITransport.data(for: urlRequest)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw LLMBackendError.requestTimedOut(request.timeoutSeconds)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMBackendError.invalidResponse("No HTTP response")
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw LLMBackendError.requestFailed(httpResponse.statusCode, message)
        }

        let content = try Self.extractContent(from: data)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMBackendError.emptyOutput
        }
        return content
    }

    // MARK: - Pure helpers (testable)

    static func buildPayload(from request: LLMChatRequest) -> [String: Any] {
        var payload: [String: Any] = [
            "model": request.model,
            "temperature": request.temperature,
            "messages": request.messages.map {
                ["role": $0.role.rawValue, "content": $0.content]
            }
        ]
        if let maxCompletionTokens = request.maxCompletionTokens {
            payload["max_completion_tokens"] = maxCompletionTokens
        }
        if let reasoningEffort = request.reasoningEffort {
            payload["reasoning_effort"] = reasoningEffort
        }
        if let includeReasoning = request.includeReasoning {
            payload["include_reasoning"] = includeReasoning
        }
        return payload
    }

    static func extractContent(from data: Data) throws -> String {
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LLMBackendError.invalidResponse("Response is not a JSON object")
            }
            json = parsed
        } catch let error as LLMBackendError {
            throw error
        } catch {
            throw LLMBackendError.invalidResponse("Failed to parse JSON: \(error.localizedDescription)")
        }

        guard let choices = json["choices"] as? [[String: Any]] else {
            throw LLMBackendError.invalidResponse("Missing 'choices' array")
        }
        guard let firstChoice = choices.first else {
            throw LLMBackendError.invalidResponse("Empty 'choices' array")
        }
        guard let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMBackendError.invalidResponse("Missing choices[0].message.content")
        }
        return content
    }
}
