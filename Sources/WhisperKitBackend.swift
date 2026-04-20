import Foundation
import WhisperKit

/// On-device transcription backend powered by WhisperKit.
///
/// The WhisperKit instance is expensive to construct (model load +
/// CoreML compile on first use), so we cache instances by model variant in a
/// shared actor pool. `TranscriptionService` creates a fresh backend per
/// dictation, but the underlying WhisperKit pipeline is reused across calls.
final class WhisperKitBackend: TranscriptionBackend {
    private let modelVariant: String?
    private let language: String?

    /// - Parameters:
    ///   - modelVariant: Hugging Face model identifier recognised by
    ///     WhisperKit (e.g. `"large-v3-v20240930_626MB"`). Pass `nil` to let
    ///     WhisperKit auto-pick the recommended model for the device.
    ///   - language: ISO 639-1 language code (e.g. `"it"`, `"en"`). Pass
    ///     `nil` (default) for automatic language detection — Whisper picks
    ///     the language itself from the audio. Explicit codes only when a
    ///     future Settings option lets the user lock the language (e.g. for
    ///     short clips where auto-detect is unreliable).
    init(modelVariant: String? = nil, language: String? = nil) {
        let trimmed = modelVariant?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelVariant = (trimmed?.isEmpty == false) ? trimmed : nil
        self.language = language
    }

    func transcribe(fileURL: URL) async throws -> String {
        try Task.checkCancellation()
        let pipe = try await WhisperKitInstancePool.shared.loadOrReturn(modelVariant: modelVariant)
        try Task.checkCancellation()
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            detectLanguage: language == nil
        )
        let results = try await pipe.transcribe(audioPath: fileURL.path, decodeOptions: options)
        let joined = results.map(\.text).joined(separator: " ")
        return joined.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Shared cache of initialised WhisperKit pipelines keyed by model variant.
/// Keeping this outside the backend class means model load latency is paid
/// only once per model per app lifetime, not once per dictation.
actor WhisperKitInstancePool {
    static let shared = WhisperKitInstancePool()

    private var cache: [String: WhisperKit] = [:]

    func loadOrReturn(modelVariant: String?) async throws -> WhisperKit {
        // A nil variant used to mean "let WhisperKit auto-select", which
        // bypassed our download manager and gave no progress UI. Now we
        // fall back to the UI default so the progress bar always works —
        // on M2+ this produces the exact same model WhisperKit would have
        // picked, so existing installs don't re-download.
        let resolvedVariant = modelVariant ?? WhisperKitModelChoice.default.whisperKitIdentifier
        if let existing = cache[resolvedVariant] {
            return existing
        }
        let folder = try await WhisperKitDownloadManager.shared.ensureModel(variant: resolvedVariant)
        let config = WhisperKitConfig(modelFolder: folder.path)
        let pipeline = try await WhisperKit(config)
        cache[resolvedVariant] = pipeline
        return pipeline
    }
}
