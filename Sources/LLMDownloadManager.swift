import Foundation

/// Observable view of MLX model download/load progress. The actual download
/// happens inside `MLXModelContainerPool` (an actor, for container cache
/// thread-safety); this @MainActor class surfaces progress to SwiftUI.
///
/// The pool signals state transitions via `setDownloading/setProgress/
/// setReady/setError`; views bind to the @Published properties.
@MainActor
final class LLMDownloadManager: ObservableObject {
    static let shared = LLMDownloadManager()

    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var progressFraction: Double = 0
    @Published private(set) var currentModelId: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var readyModelIds: Set<String> = []

    func setDownloading(modelId: String) {
        isDownloading = true
        currentModelId = modelId
        progressFraction = 0
        errorMessage = nil
    }

    func setProgress(_ fraction: Double) {
        progressFraction = fraction
    }

    func setReady(modelId: String) {
        isDownloading = false
        currentModelId = nil
        progressFraction = 1
        readyModelIds.insert(modelId)
    }

    func setError(_ message: String) {
        isDownloading = false
        currentModelId = nil
        errorMessage = message
    }

    func isReady(modelId: String) -> Bool {
        readyModelIds.contains(modelId)
    }
}
