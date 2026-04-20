import Foundation

/// Abstraction over the different ways `TranscriptionService` can produce a
/// transcript: remote OpenAI-compatible API (Groq, self-hosted) or local
/// runtimes (WhisperKit today, whisper.cpp/others in the future).
protocol TranscriptionBackend {
    func transcribe(fileURL: URL) async throws -> String
}

/// Splits a `local://` sentinel payload into its runtime name and optional
/// model variant. Example: "whisperkit/large-v3-turbo" →
/// runtime="whisperkit", modelVariant="large-v3-turbo".
struct LocalBackendIdentifier: Equatable {
    let runtime: String
    let modelVariant: String?

    static func parse(_ identifier: String) -> LocalBackendIdentifier {
        let parts = identifier.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let runtime = parts.first ?? ""
        let variant = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        return LocalBackendIdentifier(runtime: runtime, modelVariant: variant)
    }
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
