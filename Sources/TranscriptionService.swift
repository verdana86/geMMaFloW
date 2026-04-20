import AVFoundation
import Foundation

/// Thin coordinator: picks a `TranscriptionBackend` based on the configured
/// base URL, normalizes the audio once, then delegates. Preserves the
/// historic public API used by `AppState`, `SettingsView`, and `SetupView`.
class TranscriptionService {
    private let backend: TranscriptionBackend
    private let uploadSampleRate = 16_000.0
    private let uploadChannelCount: AVAudioChannelCount = 1

    init(
        apiKey: String,
        baseURL: String = "https://api.groq.com/openai/v1",
        transcriptionModel: String = "whisper-large-v3",
        transcriptionLanguage: String? = nil
    ) throws {
        let trimmedModel = transcriptionModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModel = trimmedModel.isEmpty ? "whisper-large-v3" : trimmedModel

        let trimmedLanguage = transcriptionLanguage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLanguage: String? = (trimmedLanguage?.isEmpty == false) ? trimmedLanguage : nil

        let kind = try TranscriptionBackendKind.parse(baseURL: baseURL)
        switch kind {
        case .remoteOpenAI(let url):
            self.backend = RemoteOpenAITranscriptionBackend(
                apiKey: apiKey,
                baseURL: url,
                transcriptionModel: resolvedModel
            )
        case .local(let identifier):
            let parsed = LocalBackendIdentifier.parse(identifier)
            switch parsed.runtime {
            case "whisperkit":
                self.backend = WhisperKitBackend(
                    modelVariant: parsed.modelVariant,
                    language: resolvedLanguage
                )
            default:
                self.backend = LocalTranscriptionBackend(identifier: identifier)
            }
        }
    }

    /// Validate credentials. Remote backends hit `GET {baseURL}/models` and
    /// expect 200. Local backends have nothing to validate and always return
    /// `true` — they fail at transcribe-time if the model is missing.
    static func validateAPIKey(
        _ key: String,
        baseURL: String = "https://api.groq.com/openai/v1"
    ) async -> Bool {
        guard let kind = try? TranscriptionBackendKind.parse(baseURL: baseURL) else {
            return false
        }
        switch kind {
        case .remoteOpenAI(let url):
            return await RemoteOpenAITranscriptionBackend.validateAPIKey(key, baseURL: url)
        case .local:
            return true
        }
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard !Task.isCancelled else { throw CancellationError() }

        let preparedAudio = try prepareAudioForUpload(from: fileURL)
        defer { preparedAudio.cleanup() }

        return try await backend.transcribe(fileURL: preparedAudio.fileURL)
    }

    private func prepareAudioForUpload(from fileURL: URL) throws -> PreparedUploadAudio {
        let inputFile = try AVAudioFile(forReading: fileURL)
        if isPreferredUploadFormat(file: inputFile, fileURL: fileURL) {
            return PreparedUploadAudio(fileURL: fileURL, deleteOnCleanup: false)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        do {
            try AudioNormalization.writePreferredAudioCopy(from: fileURL, to: outputURL)
        } catch {
            throw TranscriptionError.audioPreparationFailed(error.localizedDescription)
        }
        return PreparedUploadAudio(fileURL: outputURL, deleteOnCleanup: true)
    }

    private func isPreferredUploadFormat(file: AVAudioFile, fileURL: URL) -> Bool {
        let format = file.fileFormat
        return fileURL.pathExtension.lowercased() == "wav"
            && abs(format.sampleRate - uploadSampleRate) < 0.5
            && format.channelCount == uploadChannelCount
            && format.commonFormat == .pcmFormatInt16
    }
}

enum TranscriptionError: LocalizedError {
    case invalidBaseURL(String)
    case uploadFailed(String)
    case submissionFailed(String)
    case transcriptionFailed(String)
    case transcriptionTimedOut(TimeInterval)
    case pollFailed(String)
    case audioPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let msg): return "Invalid provider URL: \(msg)"
        case .uploadFailed(let msg): return "Upload failed: \(msg)"
        case .submissionFailed(let msg): return "Submission failed: \(msg)"
        case .transcriptionTimedOut(let seconds): return "Transcription timed out after \(Int(seconds))s"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        case .pollFailed(let msg): return "Polling failed: \(msg)"
        case .audioPreparationFailed(let msg): return "Audio preparation failed: \(msg)"
        }
    }
}

private struct PreparedUploadAudio {
    let fileURL: URL
    let deleteOnCleanup: Bool

    func cleanup() {
        guard deleteOnCleanup else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
