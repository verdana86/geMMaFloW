import Foundation
import os

private let cleanerLog = Logger(subsystem: "com.verdana86.gemmaflow", category: "ModelCacheCleaner")

/// Disk-level cleanup of HuggingFace-cached model weights when the user
/// switches Whisper or Gemma variant in Settings. Pairs with
/// `WhisperKitInstancePool.evict` / `MLXModelContainerPool.evict` (those
/// drop the in-RAM pipeline; this drops the on-disk weights).
enum ModelCacheCleaner {
    private static var hfCacheRoot: URL {
        // WhisperKit uses swift-transformers' HubApi which also defaults to
        // `<Documents>/huggingface/models/…` — the whisperkit-coreml repo is
        // under that same tree, so both cleanup targets live here.
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
    }

    // MARK: - Gemma (MLX)

    /// Deletes the entire HubApi repo folder for an MLX model id. HubApi
    /// stores each model as a flat directory at
    /// `<Documents>/huggingface/models/<namespace>/<repo>/` with no blob
    /// sharing across repos, so a plain `rm -rf` is safe.
    static func deleteGemmaCache(modelId: String) {
        let repoDir = hfCacheRoot.appendingPathComponent(modelId, isDirectory: true)
        guard FileManager.default.fileExists(atPath: repoDir.path) else {
            cleanerLog.info("no Gemma cache to delete at \(repoDir.path, privacy: .public)")
            return
        }
        do {
            let size = (try? folderSize(repoDir)) ?? 0
            try FileManager.default.removeItem(at: repoDir)
            cleanerLog.info("deleted Gemma cache (\(size) bytes) at \(repoDir.path, privacy: .public)")
        } catch {
            cleanerLog.error("failed to delete Gemma cache at \(repoDir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Approximate disk size of a cached Gemma model, for the
    /// "download ~X MB / free ~Y MB" confirmation dialog. Zero if missing.
    static func gemmaCacheSizeBytes(modelId: String) -> Int64 {
        let repoDir = hfCacheRoot.appendingPathComponent(modelId, isDirectory: true)
        return (try? folderSize(repoDir)) ?? 0
    }

    // MARK: - Whisper (WhisperKit-CoreML)

    /// WhisperKit uses HubApi under the hood, so all variants live as
    /// subfolders under `<Documents>/huggingface/models/argmaxinc/whisperkit-coreml/<variant>/`.
    /// Unlike the Python HF cache, there are no shared blobs between
    /// variants — each subfolder is self-contained, so `rm -rf` is safe.
    private static var whisperKitRepoRoot: URL {
        hfCacheRoot
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
    }

    static func deleteWhisperKitVariant(variant: String) {
        let variantDir = whisperKitRepoRoot.appendingPathComponent(variant, isDirectory: true)
        guard FileManager.default.fileExists(atPath: variantDir.path) else {
            cleanerLog.info("no WhisperKit variant at \(variantDir.path, privacy: .public)")
            return
        }
        do {
            let size = (try? folderSize(variantDir)) ?? 0
            try FileManager.default.removeItem(at: variantDir)
            cleanerLog.info("deleted Whisper variant (\(size) bytes) at \(variantDir.path, privacy: .public)")
        } catch {
            cleanerLog.error("failed to delete Whisper variant at \(variantDir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    static func whisperKitVariantSizeBytes(variant: String) -> Int64 {
        let variantDir = whisperKitRepoRoot.appendingPathComponent(variant, isDirectory: true)
        return (try? folderSize(variantDir)) ?? 0
    }

    // MARK: - Helpers

    /// Recursive directory size — resolves symlinks to their target because
    /// HF caches store blobs via symlinks. Without `resolveSymlinksInPath`
    /// we'd report each blob as a near-zero-byte link instead of its real
    /// payload, which would make the "free ~X MB" dialog useless.
    private static func folderSize(_ url: URL) throws -> Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        var seenInodes = Set<UInt64>()
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .fileResourceIdentifierKey
        ]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: nil
        ) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            let resolved = fileURL.resolvingSymlinksInPath()
            let values = try? resolved.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            if let identifier = values?.fileResourceIdentifier as? Data {
                // De-dup symlinks pointing at the same blob.
                let hash = identifier.withUnsafeBytes { bytes -> UInt64 in
                    var h: UInt64 = 0
                    for byte in bytes { h = h &* 31 &+ UInt64(byte) }
                    return h
                }
                guard seenInodes.insert(hash).inserted else { continue }
            }
            if let size = values?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
