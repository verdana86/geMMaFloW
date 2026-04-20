import Foundation

/// Curated language list exposed in the UI. Whisper models support 90+
/// languages; listing them all is noise. These six cover Italian, English
/// and the four other languages Whisper has shown strongest auto-translate
/// evals on (per Google/OpenAI paper results). Power users can still edit
/// the underlying ISO code directly.
///
/// Stored as the ISO 639-1 code in AppState (`""` for auto-detect). Parsing
/// is case-insensitive and unknown codes fall back to `.auto` rather than
/// erroring — we prefer "transcribe anyway" over "refuse to run".
enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case auto
    case italian
    case english
    case spanish
    case french
    case german
    case portuguese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:       return "Auto-detect"
        case .italian:    return "Italian"
        case .english:    return "English"
        case .spanish:    return "Spanish"
        case .french:     return "French"
        case .german:     return "German"
        case .portuguese: return "Portuguese"
        }
    }

    /// ISO 639-1 code. Empty string is the sentinel for "auto-detect" and
    /// matches what WhisperKit expects when `detectLanguage` is `true`.
    var isoCode: String {
        switch self {
        case .auto:       return ""
        case .italian:    return "it"
        case .english:    return "en"
        case .spanish:    return "es"
        case .french:     return "fr"
        case .german:     return "de"
        case .portuguese: return "pt"
        }
    }

    static func fromISO(_ code: String) -> TranscriptionLanguage {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first { $0.isoCode == normalized } ?? .auto
    }
}
