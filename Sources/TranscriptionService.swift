import AVFoundation
import Foundation
import os

private let silenceLog = Logger(subsystem: "com.verdana86.gemmaflow", category: "Silence")

/// Thin coordinator: picks a `TranscriptionBackend` based on the configured
/// base URL, normalizes the audio once, then delegates. Preserves the
/// historic public API used by `AppState`, `SettingsView`, and `SetupView`.
class TranscriptionService {
    private let backend: TranscriptionBackend
    private let uploadSampleRate = 16_000.0
    private let uploadChannelCount: AVAudioChannelCount = 1
    private let silenceThreshold: Float = AudioSilenceDetector.defaultThreshold

    init(
        baseURL: String = "",
        transcriptionLanguage: String? = nil
    ) {
        let trimmedLanguage = transcriptionLanguage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLanguage: String? = (trimmedLanguage?.isEmpty == false) ? trimmedLanguage : nil

        // Local-only transcription via WhisperKit. Any baseURL that isn't a
        // `local://whisperkit/...` sentinel falls back to the default variant.
        var variant: String?
        if let kind = try? TranscriptionBackendKind.parse(baseURL: baseURL),
           case .local(let identifier) = kind {
            let parsed = LocalBackendIdentifier.parse(identifier)
            if parsed.runtime == "whisperkit" {
                variant = parsed.modelVariant
            }
        }
        self.backend = WhisperKitBackend(
            modelVariant: variant,
            language: resolvedLanguage
        )
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard !Task.isCancelled else { throw CancellationError() }

        let preparedAudio = try prepareAudioForUpload(from: fileURL)
        defer { preparedAudio.cleanup() }

        // Skip transcription outright on silent clips — Whisper hallucinates
        // confident-looking text on pure silence (see AudioSilenceDetector).
        if let rms = try? AudioSilenceDetector.rms(at: preparedAudio.fileURL) {
            if rms < silenceThreshold {
                silenceLog.info("Skipping transcription: RMS \(rms, privacy: .public) < threshold \(self.silenceThreshold, privacy: .public)")
                return ""
            }
            silenceLog.debug("RMS \(rms, privacy: .public) above threshold — transcribing")
        }

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
    case transcriptionFailed(String)
    case transcriptionTimedOut(TimeInterval)
    case audioPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let msg): return "Invalid provider URL: \(msg)"
        case .transcriptionTimedOut(let seconds): return "Transcription timed out after \(Int(seconds))s"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
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
