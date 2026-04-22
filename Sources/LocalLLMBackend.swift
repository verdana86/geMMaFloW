import Foundation
import Hub
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
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

    /// Load the model container. KV cache priming used to be done here to
    /// skip system-prompt re-tokenization on every dictation (~1 s saved),
    /// but it leaked the warmup "ping" exchange into the assistant context
    /// and caused Qwen 1.5B to occasionally echo "ping" instead of cleaning
    /// the transcript. Priming disabled — we re-process the system prompt
    /// each call; this costs ~0.3–1 s but is correct 100% of the time.
    func loadOrReturnWithPrimedCache(
        modelId: String,
        systemPrompt: String
    ) async throws -> (ModelContainer, [KVCache]?) {
        let container = try await loadOrReturn(modelId: modelId)
        return (container, nil)
    }

    func loadOrReturn(modelId: String) async throws -> ModelContainer {
        llmLog.info("MLXModelContainerPool.loadOrReturn entered for \(modelId, privacy: .public)")
        if let existing = cache[modelId] {
            llmLog.info("container already cached — returning")
            await LLMDownloadManager.shared.setReady(modelId: modelId)
            return existing
        }

        await LLMDownloadManager.shared.setDownloading(modelId: modelId)

        do {
            // Ensure the HF snapshot is on disk. If it's already cached,
            // this is a quick probe; otherwise it downloads the full repo
            // via swift-huggingface and streams progress to the shared
            // LLMDownloadManager so the UI progress bar advances.
            try await Self.ensureDownloaded(modelId: modelId)

            llmLog.info("resolving local snapshot directory for \(modelId, privacy: .public)")
            let directory = try Self.resolveLocalSnapshotDirectory(for: modelId)
            llmLog.info("snapshot directory: \(directory.path, privacy: .public)")

            // Bypass #huggingFaceLoadModelContainer macro (which hangs/
            // crashes inside Downloader when loading Gemma 4). Load straight
            // from the local directory using LLMModelFactory — now that
            // ensureDownloaded has guaranteed the files exist, this is a
            // pure local-disk load.
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

    /// Download the HF snapshot for an MLX model if it isn't already
    /// cached locally. Uses swift-transformers `HubApi` (same path WhisperKit
    /// uses) because the swift-huggingface `HubClient` silently skipped the
    /// big LFS/xet-backed safetensors file on `mlx-community/gemma-*` repos.
    /// Downloads land in `~/Documents/huggingface/models/<repo-id>/` — see
    /// `resolveLocalSnapshotDirectory` for the matching read path.
    static func ensureDownloaded(modelId: String) async throws {
        let destination = hubApiModelDirectory(for: modelId)
        let safetensorsPresent = (try? FileManager.default.contentsOfDirectory(atPath: destination.path))?
            .contains(where: { $0.hasSuffix(".safetensors") }) ?? false
        if safetensorsPresent {
            llmLog.info("model \(modelId, privacy: .public) already downloaded — skip")
            return
        }

        llmLog.info("downloading HF snapshot for \(modelId, privacy: .public) via HubApi")
        _ = try await HubApi.shared.snapshot(from: modelId) { progress in
            let fraction = progress.fractionCompleted
            Task { @MainActor in
                LLMDownloadManager.shared.setProgress(fraction)
            }
        }
        llmLog.info("HF snapshot download complete for \(modelId, privacy: .public)")
    }

    /// HubApi stores downloads at `<Documents>/huggingface/models/<repo-id>/`
    /// as a flat directory (no snapshots/<rev> wrapper). Kept in one place so
    /// both `resolveLocalSnapshotDirectory` and `ModelCacheCleaner` agree on
    /// where to look.
    static func hubApiModelDirectory(for modelId: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent(modelId, isDirectory: true)
    }

    /// Drop the cached `ModelContainer` and any primed KV caches for the
    /// given model id. Callers use this before switching to a different
    /// model in Settings, so the old container's VRAM/RAM is freed and the
    /// new model can be loaded fresh. Any in-flight `loadOrReturn` for the
    /// same id serializes through the actor and completes first — this
    /// actor-level serialization is what keeps eviction race-free.
    func evict(modelId: String) {
        cache.removeValue(forKey: modelId)
        let prefix = "\(modelId)|"
        primedCaches = primedCaches.filter { !$0.key.hasPrefix(prefix) }
        Task { @MainActor in
            LLMDownloadManager.shared.markUnready(modelId: modelId)
        }
    }

    /// Return the on-disk directory for a downloaded MLX model. Matches the
    /// layout used by `ensureDownloaded` (swift-transformers `HubApi`): a
    /// flat folder per repo at `<Documents>/huggingface/models/<repo-id>/`.
    /// Throws if the expected weights file isn't present (treated as "need
    /// to download").
    static func resolveLocalSnapshotDirectory(for modelId: String) throws -> URL {
        let directory = hubApiModelDirectory(for: modelId)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        if contents.contains(where: { $0.hasSuffix(".safetensors") }) {
            return directory
        }
        throw LLMBackendError.invalidResponse(
            "Model weights missing for \(modelId). Expected a *.safetensors file under \(directory.path)."
        )
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
