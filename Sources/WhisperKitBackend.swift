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

    /// - Parameter modelVariant: Hugging Face model identifier recognised by
    ///   WhisperKit (e.g. `"large-v3-v20240930_626MB"`). Pass `nil` to let
    ///   WhisperKit auto-pick the recommended model for the device.
    init(modelVariant: String? = nil) {
        let trimmed = modelVariant?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.modelVariant = (trimmed?.isEmpty == false) ? trimmed : nil
    }

    func transcribe(fileURL: URL) async throws -> String {
        try Task.checkCancellation()
        let pipe = try await WhisperKitInstancePool.shared.loadOrReturn(modelVariant: modelVariant)
        try Task.checkCancellation()
        let results = try await pipe.transcribe(audioPath: fileURL.path)
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
        let key = modelVariant ?? "__auto__"
        if let existing = cache[key] {
            return existing
        }
        let config: WhisperKitConfig = if let modelVariant {
            WhisperKitConfig(model: modelVariant)
        } else {
            WhisperKitConfig()
        }
        let pipeline = try await WhisperKit(config)
        cache[key] = pipeline
        return pipeline
    }
}
