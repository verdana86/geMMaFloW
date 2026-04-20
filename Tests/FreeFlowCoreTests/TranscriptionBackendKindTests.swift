import Foundation
import Testing
@testable import FreeFlowCore

@Suite("TranscriptionBackendKind — routing by URL sentinel")
struct TranscriptionBackendKindTests {
    @Test("HTTPS URL routes to remote OpenAI-compatible backend")
    func httpsIsRemote() throws {
        let kind = try TranscriptionBackendKind.parse(baseURL: "https://api.groq.com/openai/v1")
        #expect(kind == .remoteOpenAI(URL(string: "https://api.groq.com/openai/v1")!))
    }

    @Test("HTTP URL also routes remote (local Ollama-compatible servers)")
    func httpIsRemote() throws {
        let kind = try TranscriptionBackendKind.parse(baseURL: "http://localhost:11434/v1")
        #expect(kind == .remoteOpenAI(URL(string: "http://localhost:11434/v1")!))
    }

    @Test("Whitespace around URL is trimmed before parsing")
    func trimsWhitespace() throws {
        let kind = try TranscriptionBackendKind.parse(baseURL: "  https://api.groq.com/openai/v1  ")
        #expect(kind == .remoteOpenAI(URL(string: "https://api.groq.com/openai/v1")!))
    }

    @Test("local://whisperkit sentinel routes to local backend")
    func localWhisperKitSentinel() throws {
        let kind = try TranscriptionBackendKind.parse(baseURL: "local://whisperkit")
        #expect(kind == .local(identifier: "whisperkit"))
    }

    @Test("local://whisperkit/turbo passes subpath as identifier detail")
    func localWithVariant() throws {
        let kind = try TranscriptionBackendKind.parse(baseURL: "local://whisperkit/large-v3-turbo")
        #expect(kind == .local(identifier: "whisperkit/large-v3-turbo"))
    }

    @Test("Empty URL throws")
    func emptyThrows() {
        #expect(throws: TranscriptionError.self) {
            try TranscriptionBackendKind.parse(baseURL: "")
        }
    }

    @Test("Malformed URL throws")
    func malformedThrows() {
        #expect(throws: TranscriptionError.self) {
            try TranscriptionBackendKind.parse(baseURL: "not a url")
        }
    }

    @Test("Unsupported scheme throws")
    func unsupportedSchemeThrows() {
        #expect(throws: TranscriptionError.self) {
            try TranscriptionBackendKind.parse(baseURL: "ftp://example.com/models")
        }
    }
}
