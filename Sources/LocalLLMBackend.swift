import Foundation
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers
import os

private let llmLog = Logger(subsystem: "com.verdana86.gemmaflow", category: "LocalLLM")

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
        llmLog.info("complete() entered for modelId=\(self.modelId, privacy: .public), messages=\(request.messages.count)")
        try Task.checkCancellation()

        let systemMessages = request.messages.filter { $0.role == .system }.map(\.content)
        let userMessages = request.messages.filter { $0.role == .user }.map(\.content)

        let instructions = systemMessages.joined(separator: "\n\n")
        let prompt = userMessages.joined(separator: "\n\n")
        llmLog.info("prompt built: promptLen=\(prompt.count), instructionsLen=\(instructions.count)")
        let promptOneLine = prompt.replacingOccurrences(of: "\n", with: " ⏎ ")
        llmLog.info("USER PROMPT: \(promptOneLine, privacy: .public)")

        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            llmLog.error("empty prompt — throwing invalidResponse")
            throw LLMBackendError.invalidResponse("LocalLLMBackend received no user messages")
        }

        llmLog.info("about to call loadOrReturnWithPrimedCache")
        let container: ModelContainer
        let primedCache: [KVCache]?
        do {
            (container, primedCache) = try await MLXModelContainerPool.shared.loadOrReturnWithPrimedCache(
                modelId: modelId,
                systemPrompt: instructions
            )
            llmLog.info("loadOrReturnWithPrimedCache returned — primedCache=\(primedCache != nil ? "HIT" : "miss", privacy: .public)")
        } catch {
            llmLog.error("loadOrReturn threw: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        try Task.checkCancellation()

        llmLog.info("creating ChatSession")
        let session: ChatSession
        if let cache = primedCache, !cache.isEmpty {
            // Use primed cache: skip re-tokenization of system prompt.
            // `instructions` must be nil — cache already encodes them.
            session = ChatSession(container, instructions: nil, cache: cache)
        } else {
            session = ChatSession(
                container,
                instructions: instructions.isEmpty ? nil : instructions
            )
        }
        llmLog.info("ChatSession created — streaming respond(to:)")

        do {
            var response = ""
            var chunkCount = 0
            var firstChunkTime: Date?
            let startTime = Date()
            for try await chunk in session.streamResponse(to: prompt) {
                if firstChunkTime == nil {
                    firstChunkTime = Date()
                    let ttft = firstChunkTime!.timeIntervalSince(startTime) * 1000
                    llmLog.info("first token at \(String(format: "%.0f", ttft), privacy: .public)ms (prompt processing)")
                }
                response += chunk
                chunkCount += 1
            }
            let total = Date().timeIntervalSince(startTime) * 1000
            let genMs = Date().timeIntervalSince(firstChunkTime ?? startTime) * 1000
            let tokPerSec = genMs > 0 ? Double(chunkCount) / (genMs / 1000) : 0
            llmLog.info("respond done: total=\(String(format: "%.0f", total), privacy: .public)ms, \(chunkCount) chunks, \(String(format: "%.1f", tokPerSec), privacy: .public) tok/s, outLen=\(response.count)")
            let outOneLine = response.replacingOccurrences(of: "\n", with: " ⏎ ")
            llmLog.info("MODEL OUTPUT: \(outOneLine, privacy: .public)")
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw LLMBackendError.emptyOutput
            }
            return response
        } catch let backendError as LLMBackendError {
            llmLog.error("LLMBackendError: \(backendError.localizedDescription, privacy: .public)")
            throw backendError
        } catch {
            llmLog.error("respond threw: \(error.localizedDescription, privacy: .public)")
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
    /// Prefix KV cache keyed by "modelId|systemPromptHash". Built once per
    /// (model, system prompt) pair — the primed state encodes the system
    /// prompt tokens plus a single warmup turn. Each dictation call clones
    /// this cache, so the warmed prefix is never mutated.
    private var primedCaches: [String: [KVCache]] = [:]

    /// Load the model container and return a fresh clone of the warmed-up
    /// KV cache for the given system prompt. Skips the warmup on subsequent
    /// calls with the same (modelId, systemPrompt) — the big win: each
    /// dictation only re-processes the ~300 tokens of user message, not the
    /// ~1200 tokens of user+system combined.
    func loadOrReturnWithPrimedCache(
        modelId: String,
        systemPrompt: String
    ) async throws -> (ModelContainer, [KVCache]?) {
        let container = try await loadOrReturn(modelId: modelId)

        guard !systemPrompt.isEmpty else { return (container, nil) }

        let cacheKey = "\(modelId)|\(systemPrompt.hashValue)"

        if let existing = primedCaches[cacheKey] {
            let cloned = existing.map { $0.copy() }
            return (container, cloned)
        }

        // Warmup: feed the system prompt + a tiny user turn through the
        // model. Persist the resulting KV cache to a temp file and reload
        // it — the public API goes through disk. Subsequent dictations
        // clone the in-memory cache so the warmed prefix is never mutated.
        llmLog.info("priming KV cache for systemPrompt hash=\(systemPrompt.hashValue, privacy: .public)")
        let warmupSession = ChatSession(
            container,
            instructions: systemPrompt,
            generateParameters: GenerateParameters(maxTokens: 4)
        )
        _ = try? await warmupSession.respond(to: "ping")
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gemmaflow-kvcache-\(abs(cacheKey.hashValue)).safetensors")
        do {
            try await warmupSession.saveCache(to: tempURL)
            let (loaded, _) = try loadPromptCache(url: tempURL)
            try? FileManager.default.removeItem(at: tempURL)
            primedCaches[cacheKey] = loaded.map { $0.copy() }
            let cloned = loaded.map { $0.copy() }
            llmLog.info("KV cache primed — stored and clone returned")
            return (container, cloned)
        } catch {
            llmLog.error("KV cache priming failed: \(error.localizedDescription, privacy: .public) — falling back to instructions")
            try? FileManager.default.removeItem(at: tempURL)
            return (container, nil)
        }
    }

    func loadOrReturn(modelId: String) async throws -> ModelContainer {
        llmLog.info("MLXModelContainerPool.loadOrReturn entered for \(modelId, privacy: .public)")
        if let existing = cache[modelId] {
            llmLog.info("container already cached — returning")
            await LLMDownloadManager.shared.setReady(modelId: modelId)
            return existing
        }

        await LLMDownloadManager.shared.setDownloading(modelId: modelId)

        // Bypass #huggingFaceLoadModelContainer macro (which hangs/crashes
        // inside Downloader when loading Gemma 4). Resolve the HuggingFace
        // cache snapshot path and load straight from that local directory
        // using LLMModelFactory. The model must be pre-downloaded into
        // ~/.cache/huggingface/hub/... (e.g. via `huggingface-cli download`).
        do {
            llmLog.info("resolving local snapshot directory for \(modelId, privacy: .public)")
            let directory = try Self.resolveLocalSnapshotDirectory(for: modelId)
            llmLog.info("snapshot directory: \(directory.path, privacy: .public)")

            llmLog.info("about to call LLMModelFactory.shared.loadContainer(from:using:)")
            let container = try await LLMModelFactory.shared.loadContainer(
                from: directory,
                using: #huggingFaceTokenizerLoader()
            )
            llmLog.info("loadContainer returned successfully")
            cache[modelId] = container
            await LLMDownloadManager.shared.setReady(modelId: modelId)
            return container
        } catch {
            llmLog.error("loadContainer threw: \(error.localizedDescription, privacy: .public)")
            await LLMDownloadManager.shared.setError(error.localizedDescription)
            throw error
        }
    }

    /// Resolve the HuggingFace Hub cache snapshot directory for a given
    /// model repo id. Assumes the model has been pre-downloaded into
    /// `~/.cache/huggingface/hub/models--<slug>/snapshots/<rev>/`.
    static func resolveLocalSnapshotDirectory(for modelId: String) throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let slug = modelId.replacingOccurrences(of: "/", with: "--")
        let repoRoot = home
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
            .appendingPathComponent("models--\(slug)", isDirectory: true)

        let refsMain = repoRoot.appendingPathComponent("refs").appendingPathComponent("main")
        if let commitHash = try? String(contentsOf: refsMain, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !commitHash.isEmpty {
            let snapshot = repoRoot
                .appendingPathComponent("snapshots", isDirectory: true)
                .appendingPathComponent(commitHash, isDirectory: true)
            if FileManager.default.fileExists(atPath: snapshot.path) {
                return snapshot
            }
        }

        // Fallback: pick the first subdirectory under snapshots/.
        let snapshotsDir = repoRoot.appendingPathComponent("snapshots", isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil)) ?? []
        if let first = contents.first {
            return first
        }

        throw LLMBackendError.invalidResponse("Model not found in local HuggingFace cache: \(modelId). Run: huggingface-cli download \(modelId)")
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
