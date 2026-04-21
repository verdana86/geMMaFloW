import Foundation
import os

private let cleanerLog = Logger(subsystem: "com.verdana86.gemmaflow", category: "ModelCacheCleaner")

/// Disk-level cleanup of HuggingFace-cached model weights when the user
/// switches Whisper or Gemma variant in Settings. Pairs with
/// `WhisperKitInstancePool.evict` / `MLXModelContainerPool.evict` (those
/// drop the in-RAM pipeline; this drops the on-disk weights).
enum ModelCacheCleaner {
    private static var hfCacheRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
    }

    // MARK: - Gemma (MLX)

    /// Deletes the entire HF repo folder for an MLX model id. Each Gemma
    /// variant is a standalone repo (e.g. `mlx-community/gemma-4-e4b-it-4bit`
    /// ↔ `mlx-community/gemma-4-e2b-it-4bit`) so removing the top-level repo
    /// folder is sufficient — no shared blobs across variants.
    static func deleteGemmaCache(modelId: String) {
        let slug = modelId.replacingOccurrences(of: "/", with: "--")
        let repoDir = hfCacheRoot.appendingPathComponent("models--\(slug)", isDirectory: true)
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
        let slug = modelId.replacingOccurrences(of: "/", with: "--")
        let repoDir = hfCacheRoot.appendingPathComponent("models--\(slug)", isDirectory: true)
        return (try? folderSize(repoDir)) ?? 0
    }

    // MARK: - Whisper (WhisperKit-CoreML)

    /// Delete a WhisperKit variant's snapshot subfolder. WhisperKit ships
    /// all variants under a single HF repo (`argmaxinc/whisperkit-coreml`),
    /// so we can't `rm -rf` the whole repo without taking out every variant.
    /// We only unlink the variant folder under `snapshots/<rev>/<variant>/`;
    /// the underlying content-addressed blobs in `blobs/` may linger until
    /// `make prune-hf-cache` runs a GC pass. Acceptable tradeoff — blobs
    /// without pointing snapshot links are ~dead weight, not re-downloaded.
    static func deleteWhisperKitVariant(variant: String) {
        let repoDir = hfCacheRoot.appendingPathComponent("models--argmaxinc--whisperkit-coreml", isDirectory: true)
        let snapshotsDir = repoDir.appendingPathComponent("snapshots", isDirectory: true)
        guard FileManager.default.fileExists(atPath: snapshotsDir.path) else {
            cleanerLog.info("no WhisperKit snapshots root at \(snapshotsDir.path, privacy: .public)")
            return
        }
        let revisions = (try? FileManager.default.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil)) ?? []
        for revisionDir in revisions {
            let variantDir = revisionDir.appendingPathComponent(variant, isDirectory: true)
            guard FileManager.default.fileExists(atPath: variantDir.path) else { continue }
            do {
                let size = (try? folderSize(variantDir)) ?? 0
                try FileManager.default.removeItem(at: variantDir)
                cleanerLog.info("deleted Whisper variant dir (\(size) bytes) at \(variantDir.path, privacy: .public)")
            } catch {
                cleanerLog.error("failed to delete Whisper variant at \(variantDir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func whisperKitVariantSizeBytes(variant: String) -> Int64 {
        let repoDir = hfCacheRoot.appendingPathComponent("models--argmaxinc--whisperkit-coreml", isDirectory: true)
        let snapshotsDir = repoDir.appendingPathComponent("snapshots", isDirectory: true)
        guard let revisions = try? FileManager.default.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil) else {
            return 0
        }
        var total: Int64 = 0
        for revisionDir in revisions {
            let variantDir = revisionDir.appendingPathComponent(variant, isDirectory: true)
            if FileManager.default.fileExists(atPath: variantDir.path) {
                total += (try? folderSize(variantDir)) ?? 0
            }
        }
        return total
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
