import Foundation

/// Curated subset of WhisperKit-CoreML model variants exposed in the UI.
/// The underlying Hugging Face repo ships 27 variants; three presets cover
/// the useful trade-offs between size, speed, and quality.
///
/// "Auto" was intentionally removed: WhisperKit's internal auto-select
/// bypasses our progress callback and downloads silently (a UX regression).
/// Forcing an explicit preset keeps the progress bar reliable on every
/// first-run.
enum WhisperKitModelChoice: String, CaseIterable, Identifiable {
    case turbo
    case large
    case small

    /// Default when the user opts into WhisperKit without picking a preset.
    /// Large matches what WhisperKit would auto-select on M2+ — stable across
    /// model loads. Turbo is faster but hangs on load under some conditions
    /// (needs investigation). Users who want faster cold starts switch to
    /// Turbo manually from Settings.
    static let `default`: WhisperKitModelChoice = .large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .turbo: return "Turbo — fast + accurate (~630 MB)"
        case .large: return "Large-v3 — most accurate (~1.5 GB)"
        case .small: return "Small — low-latency (~220 MB)"
        }
    }

    /// Hugging Face folder name inside `argmaxinc/whisperkit-coreml`.
    var whisperKitIdentifier: String {
        switch self {
        case .turbo: return "openai_whisper-large-v3-v20240930_turbo_632MB"
        case .large: return "openai_whisper-large-v3-v20240930"
        case .small: return "openai_whisper-small_216MB"
        }
    }

    /// Encodes the choice as a `local://whisperkit/<variant>` sentinel used
    /// by `TranscriptionBackendKind` routing.
    var sentinelBaseURL: String {
        "local://whisperkit/\(whisperKitIdentifier)"
    }

    /// Recovers the matching preset from a stored baseURL. Bare
    /// `local://whisperkit` (no variant — legacy storage from the era when
    /// Auto was a preset) migrates to `.large` so existing installs keep
    /// working without a re-download. Custom variants not in the curated
    /// list return `nil` — the UI falls through to free-form text editing.
    static func fromSentinelBaseURL(_ baseURL: String) -> WhisperKitModelChoice? {
        guard let kind = try? TranscriptionBackendKind.parse(baseURL: baseURL),
              case .local(let identifier) = kind else {
            return nil
        }
        let parsed = LocalBackendIdentifier.parse(identifier)
        guard parsed.runtime == "whisperkit" else { return nil }
        guard let variant = parsed.modelVariant else {
            return .default  // legacy bare URL → migrate to default
        }
        return allCases.first { $0.whisperKitIdentifier == variant }
    }
}
