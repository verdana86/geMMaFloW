import Foundation
import WhisperKit

/// Observable wrapper around `WhisperKit.download` that surfaces progress to
/// the UI. Without this, the first dictation with a fresh model "freezes"
/// for 1-3 minutes while the underlying HuggingFace snapshot runs silently.
///
/// The manager caches resolved folder URLs so flipping between variants in
/// Settings only pays the download cost once per variant per process.
@MainActor
final class WhisperKitDownloadManager: ObservableObject {
    static let shared = WhisperKitDownloadManager()

    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var progressFraction: Double = 0
    @Published private(set) var statusText: String = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentVariant: String?

    private var downloadedFolders: [String: URL] = [:]
    private var activeDownload: Task<URL, Error>?

    /// Downloads (or reuses) the model folder for the given variant and
    /// returns the local URL suitable for `WhisperKitConfig.modelFolder`.
    /// Concurrent callers requesting the same variant share a single
    /// in-flight download.
    func ensureModel(variant: String) async throws -> URL {
        if let cached = downloadedFolders[variant] {
            return cached
        }
        if let active = activeDownload, currentVariant == variant {
            return try await active.value
        }

        errorMessage = nil
        isDownloading = true
        progressFraction = 0
        currentVariant = variant
        statusText = "Downloading \(variant)…"

        let task = Task<URL, Error> { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    self?.isDownloading = false
                    self?.activeDownload = nil
                    self?.statusText = ""
                }
            }
            do {
                let folder = try await WhisperKit.download(variant: variant) { progress in
                    Task { @MainActor [weak self] in
                        self?.progressFraction = progress.fractionCompleted
                    }
                }
                await MainActor.run { [weak self] in
                    self?.downloadedFolders[variant] = folder
                    self?.progressFraction = 1.0
                }
                return folder
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
                throw error
            }
        }
        activeDownload = task
        return try await task.value
    }

    func cachedFolder(for variant: String) -> URL? {
        downloadedFolders[variant]
    }
}
