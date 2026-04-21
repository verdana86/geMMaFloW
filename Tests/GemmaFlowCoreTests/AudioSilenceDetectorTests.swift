import AVFoundation
import Foundation
import Testing
@testable import GemmaFlowCore

@Suite("AudioSilenceDetector — skips Whisper on silent clips")
struct AudioSilenceDetectorTests {
    @Test("Pure silence RMS is below the default threshold")
    func silentBufferIsBelowThreshold() throws {
        let url = try writeTone(amplitude: 0.0, durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }
        let rms = try AudioSilenceDetector.rms(at: url)
        #expect(rms < AudioSilenceDetector.defaultThreshold)
        #expect(try AudioSilenceDetector.isSilent(at: url))
    }

    @Test("A 0.3-amplitude tone is above the default threshold")
    func toneBufferIsAboveThreshold() throws {
        let url = try writeTone(amplitude: 0.3, durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }
        let rms = try AudioSilenceDetector.rms(at: url)
        #expect(rms > AudioSilenceDetector.defaultThreshold)
        #expect(try !AudioSilenceDetector.isSilent(at: url))
    }

    // MARK: - Helpers

    private func writeTone(amplitude: Float, durationSeconds: Double) throws -> URL {
        let sampleRate = 16_000.0
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            throw SilenceTestError.formatFailure
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SilenceTestError.bufferFailure
        }
        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else {
            throw SilenceTestError.bufferFailure
        }
        let frequency: Float = 440.0
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            channel[i] = amplitude == 0 ? 0 : amplitude * sinf(2.0 * .pi * frequency * t)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}

private enum SilenceTestError: Error {
    case formatFailure
    case bufferFailure
}
