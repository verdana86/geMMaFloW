import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

/// In-process LLM backend powered by MLX Swift. Downloads a quantized Gemma
/// model from HuggingFace on first use, caches the loaded `ModelContainer`
/// for subsequent calls (model load is expensive — tens of seconds on M1,
/// a few seconds on M3+).
///
/// Multi-turn / system-prompt semantics: we collapse all `.system` messages
/// into `ChatSession.instructions`, concatenate all `.user` messages into
/// the single prompt passed to `respond(to:)`. We spin up a fresh
/// `ChatSession` per call so there's no conversation carry-over — matches
/// how `PostProcessingService` expects stateless, one-shot completions.
final class LocalLLMBackend: LLMBackend {
    private let modelId: String

    init(modelId: String) {
        self.modelId = modelId
    }

    func complete(_ request: LLMChatRequest) async throws -> String {
        try Task.checkCancellation()
        let container = try await MLXModelContainerPool.shared.loadOrReturn(modelId: modelId)
        try Task.checkCancellation()

        let systemMessages = request.messages.filter { $0.role == .system }.map(\.content)
        let userMessages = request.messages.filter { $0.role == .user }.map(\.content)

        let instructions = systemMessages.joined(separator: "\n\n")
        let prompt = userMessages.joined(separator: "\n\n")

        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMBackendError.invalidResponse("LocalLLMBackend received no user messages")
        }

        let session = ChatSession(
            container,
            instructions: instructions.isEmpty ? nil : instructions
        )

        do {
            let response = try await session.respond(to: prompt)
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw LLMBackendError.emptyOutput
            }
            return response
        } catch let backendError as LLMBackendError {
            throw backendError
        } catch {
            throw LLMBackendError.invalidResponse(error.localizedDescription)
        }
    }
}

/// Shared cache of loaded MLX `ModelContainer` instances keyed by model id.
/// Loading a container is expensive (disk I/O + model materialization +
/// tokenizer setup) so we pay it once per model per process and reuse the
/// container across dictations.
actor MLXModelContainerPool {
    static let shared = MLXModelContainerPool()

    private var cache: [String: ModelContainer] = [:]

    func loadOrReturn(modelId: String) async throws -> ModelContainer {
        if let existing = cache[modelId] {
            return existing
        }
        let configuration = Self.resolveConfiguration(for: modelId)
        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration
        )
        cache[modelId] = container
        return container
    }

    /// Map a stored model id (string from settings) to an MLX
    /// `ModelConfiguration`. When the id matches one of the curated presets
    /// we pass through the richer configuration from `LLMRegistry` (carries
    /// the right EOS tokens); for any other id we fall back to a bare
    /// configuration that just wraps the HuggingFace repo path.
    static func resolveConfiguration(for modelId: String) -> ModelConfiguration {
        if modelId == LLMRegistry.gemma4_e4b_it_4bit.name {
            return LLMRegistry.gemma4_e4b_it_4bit
        }
        if modelId == LLMRegistry.gemma4_e2b_it_4bit.name {
            return LLMRegistry.gemma4_e2b_it_4bit
        }
        return ModelConfiguration(id: modelId)
    }
}
