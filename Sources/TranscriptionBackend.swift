import Foundation

/// Abstraction over the different ways `TranscriptionService` can produce a
/// transcript: remote OpenAI-compatible API (Groq, self-hosted) today, local
/// runtimes (WhisperKit and friends) once Step 2b lands.
protocol TranscriptionBackend {
    func transcribe(fileURL: URL) async throws -> String
}

/// Routing decision based on the configured transcription base URL. Pure
/// enum + static parser so the selection is testable without instantiating
/// any backend.
enum TranscriptionBackendKind: Equatable {
    case remoteOpenAI(URL)
    case local(identifier: String)

    static func parse(baseURL: String) throws -> TranscriptionBackendKind {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranscriptionError.invalidBaseURL("Provider URL is empty.")
        }
        guard var components = URLComponents(string: trimmed) else {
            throw TranscriptionError.invalidBaseURL("Provider URL is malformed.")
        }
        let scheme = components.scheme?.lowercased() ?? ""

        switch scheme {
        case "http", "https":
            guard let host = components.host, !host.isEmpty else {
                throw TranscriptionError.invalidBaseURL("Provider URL must include a host.")
            }
            components.scheme = scheme
            if components.path == "/" {
                components.path = ""
            } else {
                components.path = components.path.replacingOccurrences(
                    of: "/+$",
                    with: "",
                    options: .regularExpression
                )
            }
            guard let url = components.url else {
                throw TranscriptionError.invalidBaseURL("Provider URL is malformed.")
            }
            return .remoteOpenAI(url)

        case "local":
            let host = components.host ?? ""
            var identifier = host
            if !components.path.isEmpty && components.path != "/" {
                identifier += components.path
            }
            guard !identifier.isEmpty else {
                throw TranscriptionError.invalidBaseURL("local:// URL must include an identifier.")
            }
            return .local(identifier: identifier)

        default:
            throw TranscriptionError.invalidBaseURL("Provider URL must use http, https, or local scheme.")
        }
    }
}
