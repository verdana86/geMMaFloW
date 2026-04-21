import Foundation
import os.log

private let remoteBackendLog = OSLog(subsystem: "com.verdana86.gemmaflow", category: "Transcription.RemoteOpenAI")

/// Transcription backend that speaks to an OpenAI-compatible
/// `/audio/transcriptions` endpoint (Groq, self-hosted Whisper, etc.).
/// Expects audio already normalized to the provider's preferred format
/// (16 kHz mono PCM int16 WAV) — `TranscriptionService` handles the prep.
final class RemoteOpenAITranscriptionBackend: TranscriptionBackend {
    private let apiKey: String
    private let baseURL: URL
    private let transcriptionModel: String
    private let filter: HallucinationFilter
    private let responseFormat = "verbose_json"
    private let timeoutSeconds: TimeInterval = 20

    init(
        apiKey: String,
        baseURL: URL,
        transcriptionModel: String,
        filter: HallucinationFilter = .whisperDefault
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.transcriptionModel = transcriptionModel
        self.filter = filter
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard !Task.isCancelled else { throw CancellationError() }
        do {
            return try await postMultipart(fileURL: fileURL)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw TranscriptionError.transcriptionTimedOut(timeoutSeconds)
        }
    }

    static func validateAPIKey(_ key: String, baseURL: URL) async -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.timeoutInterval = 10
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await LLMAPITransport.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return status == 200
        } catch {
            return false
        }
    }

    private func postMultipart(fileURL: URL) async throws -> String {
        let url = baseURL
            .appendingPathComponent("audio")
            .appendingPathComponent("transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        let body = makeMultipartBody(
            audioData: audioData,
            fileName: fileURL.lastPathComponent,
            boundary: boundary
        )

        do {
            let (data, response) = try await LLMAPITransport.upload(for: request, from: body)
            return try validateResponse(data: data, response: response, fileURL: fileURL)
        } catch {
            let nsError = error as NSError
            os_log(
                .error,
                log: remoteBackendLog,
                "URLSession upload failed for %{public}@ (bytes=%{public}lld): domain=%{public}@ code=%ld desc=%{public}@",
                fileURL.lastPathComponent,
                fileSizeBytes(for: fileURL),
                nsError.domain,
                nsError.code,
                error.localizedDescription
            )
            throw error
        }
    }

    private func validateResponse(data: Data, response: URLResponse, fileURL: URL) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.submissionFailed("No response from server")
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            os_log(
                .error,
                log: remoteBackendLog,
                "URLSession upload returned HTTP %ld for %{public}@ (bytes=%{public}lld)",
                httpResponse.statusCode,
                fileURL.lastPathComponent,
                fileSizeBytes(for: fileURL)
            )
            throw TranscriptionError.submissionFailed("Status \(httpResponse.statusCode): \(responseBody)")
        }

        return try parseTranscript(from: data)
    }

    private func parseTranscript(from data: Data) throws -> String {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            let segments = json["segments"] as? [[String: Any]]
            let firstNoSpeechProb = segments?.first?["no_speech_prob"] as? Double
            if filter.isHallucination(text: text, noSpeechProb: firstNoSpeechProb) {
                return ""
            }
            return text
        }

        let plainText = String(data: data, encoding: .utf8) ?? ""
        let text = plainText
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.pollFailed("Invalid response")
        }
        return text
    }

    private func audioContentType(for fileName: String) -> String {
        if fileName.lowercased().hasSuffix(".wav") { return "audio/wav" }
        if fileName.lowercased().hasSuffix(".mp3") { return "audio/mpeg" }
        if fileName.lowercased().hasSuffix(".m4a") { return "audio/mp4" }
        return "audio/mp4"
    }

    private func fileSizeBytes(for fileURL: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? -1
    }

    private func makeMultipartBody(audioData: Data, fileName: String, boundary: String) -> Data {
        var body = Data()

        func append(_ value: String) {
            body.append(Data(value.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(transcriptionModel)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("\(responseFormat)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(audioContentType(for: fileName))\r\n\r\n")
        body.append(audioData)
        append("\r\n")
        append("--\(boundary)--\r\n")

        return body
    }
}

/// Placeholder for the local (WhisperKit) backend landing in Step 2b. Keeping
/// it present so the factory routing already compiles and is exercised by
/// tests — the actual WhisperKit wiring will replace the body.
final class LocalTranscriptionBackend: TranscriptionBackend {
    let identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }

    func transcribe(fileURL: URL) async throws -> String {
        throw TranscriptionError.transcriptionFailed(
            "Local transcription backend '\(identifier)' is not yet implemented (Step 2b)."
        )
    }
}
