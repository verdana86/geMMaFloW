import Foundation

/// Curated list of bundled LLM presets the UI offers. MLX's registry
/// includes dozens of models; exposing all would overwhelm. These two
/// cover the "quality" and "speed" slots for Gemma 4 at 4-bit
/// quantization.
enum LocalLLMModelChoice: String, CaseIterable, Identifiable {
    case gemma4E4B4bit
    case gemma4E2B4bit

    /// Default when the user opts into local LLM without picking a preset.
    /// E4B is the best quality at an acceptable 3.8 GB on disk.
    static let `default`: LocalLLMModelChoice = .gemma4E4B4bit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemma4E4B4bit: return "Gemma 4 E4B — best quality (~3.8 GB)"
        case .gemma4E2B4bit: return "Gemma 4 E2B — lighter (~1.7 GB)"
        }
    }

    /// Matches the repo id stored in MLX's `LLMRegistry` presets. Kept as a
    /// literal so the enum compiles without importing MLXLLM (keeps pure
    /// data tests cheap).
    var mlxModelId: String {
        switch self {
        case .gemma4E4B4bit: return "mlx-community/gemma-4-e4b-it-4bit"
        case .gemma4E2B4bit: return "mlx-community/gemma-4-e2b-it-4bit"
        }
    }

    var sentinelBaseURL: String {
        "local://mlx/\(mlxModelId)"
    }

    static func fromSentinelBaseURL(_ baseURL: String) -> LocalLLMModelChoice? {
        guard let kind = try? LLMBackendKind.parse(baseURL: baseURL),
              case .localMLX(let modelId) = kind else {
            return nil
        }
        guard let modelId else {
            return .default  // bare local://mlx → migrate to default
        }
        return allCases.first { $0.mlxModelId == modelId }
    }
}
