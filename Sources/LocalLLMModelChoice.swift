import Foundation

/// Curated list of bundled LLM presets the UI offers. MLX's registry
/// includes dozens of models; exposing all would overwhelm. The three
/// options cover the full quality/speed trade-off surface for dictation
/// cleanup at 4-bit quantization — from Qwen 2.5 1.5B (fastest, ~870 MB)
/// through Gemma 4 E2B to Gemma 4 E4B (most accurate, ~5 GB).
enum LocalLLMModelChoice: String, CaseIterable, Identifiable {
    case qwen25_15B4bit
    case gemma4E2B4bit
    case gemma4E4B4bit

    /// Default when the user opts into local LLM without picking a preset.
    /// Qwen 2.5 1.5B is ~6× smaller than Gemma 4 E4B and post-processes
    /// typical dictation in well under a second on Apple Silicon, vs
    /// Gemma E4B's multi-second runs. Quality is comparable for the
    /// narrow "strip fillers, fix punctuation" task the pipeline needs,
    /// so we favor the lighter default and surface Gemma as the
    /// "higher-quality, slower" opt-in.
    static let `default`: LocalLLMModelChoice = .qwen25_15B4bit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qwen25_15B4bit: return "Qwen 2.5 1.5B — lightest, fastest (~870 MB)"
        case .gemma4E2B4bit: return "Gemma 4 E2B — balanced (~3.5 GB)"
        case .gemma4E4B4bit: return "Gemma 4 E4B — best quality (~5 GB)"
        }
    }

    /// Matches the repo id stored in MLX's `LLMRegistry` presets. Kept as a
    /// literal so the enum compiles without importing MLXLLM (keeps pure
    /// data tests cheap).
    var mlxModelId: String {
        switch self {
        case .qwen25_15B4bit: return "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        case .gemma4E2B4bit: return "mlx-community/gemma-4-e2b-it-4bit"
        case .gemma4E4B4bit: return "mlx-community/gemma-4-e4b-it-4bit"
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
