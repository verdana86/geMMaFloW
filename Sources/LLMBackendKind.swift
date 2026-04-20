import Foundation

/// Routing decision for `PostProcessingService` (and future
/// `AppContextService`) based on the configured LLM base URL. Remote
/// OpenAI-compatible endpoints keep their URL; `local://mlx[/<modelId>]`
/// sentinels route to `LocalLLMBackend` with the given MLX repo id (or
/// default when bare).
enum LLMBackendKind: Equatable {
    case remoteOpenAI(String)
    case localMLX(modelId: String?)

    static func parse(baseURL: String) throws -> LLMBackendKind {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LLMBackendError.invalidResponse("LLM base URL is empty.")
        }
        guard let components = URLComponents(string: trimmed) else {
            throw LLMBackendError.invalidResponse("LLM base URL is malformed.")
        }
        let scheme = components.scheme?.lowercased() ?? ""

        switch scheme {
        case "http", "https":
            return .remoteOpenAI(trimmed)

        case "local":
            guard components.host?.lowercased() == "mlx" else {
                throw LLMBackendError.invalidResponse(
                    "Only 'local://mlx' is supported as a local LLM runtime today."
                )
            }
            // Path is either empty ("local://mlx") or "/<repo>/<model>"
            let rawPath = components.path
            let modelPath = rawPath.hasPrefix("/") ? String(rawPath.dropFirst()) : rawPath
            if modelPath.isEmpty {
                return .localMLX(modelId: nil)
            }
            return .localMLX(modelId: modelPath)

        default:
            throw LLMBackendError.invalidResponse(
                "LLM base URL must use http, https, or local scheme."
            )
        }
    }
}
