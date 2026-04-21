import AVFoundation
import Foundation

/// Computes the RMS (root mean square) amplitude of a PCM audio file.
/// Used as a pre-filter before WhisperKit transcription: silent clips
/// (RMS below threshold) skip transcription entirely, which avoids the
/// well-known Whisper behaviour of hallucinating plausible-looking
/// sentences on pure silence (e.g. producing `"killall geMMaFloW..."`
/// or "Thanks for watching" out of thin air).
enum AudioSilenceDetector {
    /// Default threshold tuned empirically on 16kHz mono PCM16 clips.
    /// ≈ -54 dBFS — conservative: below this value there is essentially no
    /// voice energy, only ambient electrical noise. Calibrate higher
    /// (0.004–0.008) if false negatives appear.
    static let defaultThreshold: Float = 0.002

    /// Returns the normalised RMS of the file content. Values are in
    /// `[0, 1]` where 1 corresponds to a full-scale signal.
    /// Throws if the file cannot be opened or decoded.
    static func rms(at url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0 else { return 0 }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return 0
        }
        try file.read(into: buffer)

        let actualFrames = Int(buffer.frameLength)
        guard actualFrames > 0 else { return 0 }
        let channelCount = Int(format.channelCount)

        var sumOfSquares: Double = 0
        var sampleCount: Int = 0

        if let floatChannels = buffer.floatChannelData {
            for ch in 0..<channelCount {
                let channel = floatChannels[ch]
                for i in 0..<actualFrames {
                    let sample = Double(channel[i])
                    sumOfSquares += sample * sample
                }
                sampleCount += actualFrames
            }
        } else if let int16Channels = buffer.int16ChannelData {
            let scale = 1.0 / Double(Int16.max)
            for ch in 0..<channelCount {
                let channel = int16Channels[ch]
                for i in 0..<actualFrames {
                    let sample = Double(channel[i]) * scale
                    sumOfSquares += sample * sample
                }
                sampleCount += actualFrames
            }
        } else {
            return 0
        }

        guard sampleCount > 0 else { return 0 }
        return Float(sqrt(sumOfSquares / Double(sampleCount)))
    }

    static func isSilent(at url: URL, threshold: Float = defaultThreshold) throws -> Bool {
        let value = try rms(at: url)
        return value < threshold
    }
}
