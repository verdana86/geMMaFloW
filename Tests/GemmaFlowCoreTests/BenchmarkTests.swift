import Foundation
import Testing
@testable import GemmaFlowCore

/// Cross-product benchmark: (Whisper Small, Whisper Large) × (Gemma E2B,
/// Gemma E4B) × (20 s, 40 s, 60 s, full) on the TTS-generated reference
/// audio. Skips itself unless `BENCH_AUDIO_DIR` is set — so normal `swift
/// test` runs stay fast. Writes `bench/results.md` with a markdown table.
///
/// Run via `scripts/run-bench.sh`.
@Suite("Benchmark matrix")
struct BenchmarkTests {
    @Test("Run Whisper × Gemma × length matrix")
    func runMatrix() async throws {
        guard let audioDirPath = ProcessInfo.processInfo.environment["BENCH_AUDIO_DIR"] else {
            // Not in bench mode — pass trivially so `swift test` stays clean.
            return
        }
        let audioDir = URL(fileURLWithPath: audioDirPath)

        let lengths: [(label: String, file: String)] = [
            ("20s", "20s.wav"),
            ("40s", "40s.wav"),
            ("60s", "60s.wav"),
            ("full", "full.wav")
        ]

        let whisperChoices: [(label: String, choice: WhisperKitModelChoice)] = [
            ("Whisper Small", .small),
            ("Whisper Large", .large)
        ]

        let gemmaChoices: [(label: String, choice: LocalLLMModelChoice)] = [
            ("Gemma E2B", .gemma4E2B4bit),
            ("Gemma E4B", .gemma4E4B4bit)
        ]

        struct Row {
            let lengthLabel: String
            let whisperLabel: String
            let gemmaLabel: String
            let whisperMs: Double
            let gemmaMs: Double
            let rawTranscript: String
            let cleanedTranscript: String
            let error: String?
        }
        var rows: [Row] = []

        // Warm every model once up-front so the first benchmark run isn't
        // skewed by download + ANE specialisation + KV-cache priming.
        let warmupAudio = audioDir.appendingPathComponent(lengths.first!.file)
        for whisper in whisperChoices {
            print("→ Warming \(whisper.label)…")
            let svc = TranscriptionService(
                baseURL: whisper.choice.sentinelBaseURL,
                transcriptionLanguage: "en"
            )
            _ = try await svc.transcribe(fileURL: warmupAudio)
        }
        for gemma in gemmaChoices {
            print("→ Warming \(gemma.label)…")
            let pp = PostProcessingService(baseURL: gemma.choice.sentinelBaseURL)
            _ = try? await pp.postProcess(
                transcript: "Hello, this is a warmup sentence.",
                context: benchContext(),
                customVocabulary: "",
                customSystemPrompt: ""
            )
        }

        // Actual matrix — loop length-outer, whisper-middle, gemma-inner so
        // we transcribe each (length × whisper) once and reuse the raw
        // transcript across gemma variants.
        for length in lengths {
            let audioURL = audioDir.appendingPathComponent(length.file)
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                print("skip missing: \(audioURL.path)")
                continue
            }

            for whisper in whisperChoices {
                print("→ Transcribing \(length.label) with \(whisper.label)…")
                let tStart = Date()
                let raw: String
                do {
                    let svc = TranscriptionService(
                        baseURL: whisper.choice.sentinelBaseURL,
                        transcriptionLanguage: "en"
                    )
                    raw = try await svc.transcribe(fileURL: audioURL)
                } catch {
                    for gemma in gemmaChoices {
                        rows.append(Row(
                            lengthLabel: length.label,
                            whisperLabel: whisper.label,
                            gemmaLabel: gemma.label,
                            whisperMs: Date().timeIntervalSince(tStart) * 1000,
                            gemmaMs: 0,
                            rawTranscript: "",
                            cleanedTranscript: "",
                            error: "whisper: \(error.localizedDescription)"
                        ))
                    }
                    continue
                }
                let whisperMs = Date().timeIntervalSince(tStart) * 1000

                for gemma in gemmaChoices {
                    print("  → Post-processing with \(gemma.label)…")
                    let pp = PostProcessingService(baseURL: gemma.choice.sentinelBaseURL)
                    let gStart = Date()
                    do {
                        let result = try await pp.postProcess(
                            transcript: raw,
                            context: benchContext(),
                            customVocabulary: "",
                            customSystemPrompt: ""
                        )
                        let gemmaMs = Date().timeIntervalSince(gStart) * 1000
                        rows.append(Row(
                            lengthLabel: length.label,
                            whisperLabel: whisper.label,
                            gemmaLabel: gemma.label,
                            whisperMs: whisperMs,
                            gemmaMs: gemmaMs,
                            rawTranscript: raw,
                            cleanedTranscript: result.transcript,
                            error: nil
                        ))
                    } catch {
                        let gemmaMs = Date().timeIntervalSince(gStart) * 1000
                        rows.append(Row(
                            lengthLabel: length.label,
                            whisperLabel: whisper.label,
                            gemmaLabel: gemma.label,
                            whisperMs: whisperMs,
                            gemmaMs: gemmaMs,
                            rawTranscript: raw,
                            cleanedTranscript: "",
                            error: "gemma: \(error.localizedDescription)"
                        ))
                    }
                }
            }
        }

        // Render markdown: latency table first (at-a-glance), then per-row
        // transcripts (what each combo actually produced) so we can inspect
        // quality degradation alongside speed.
        var md = "# GemmaFlow benchmark\n\n"
        md += "Audio source: ElevenLabs TTS (Rachel, `eleven_turbo_v2_5`). "
        md += "Reference text: see `bench/reference.txt`.\n\n"
        md += "Device: `\(ProcessInfo.processInfo.hostName)`, "
        md += "macOS \(ProcessInfo.processInfo.operatingSystemVersionString).\n\n"
        md += "## Latency (ms)\n\n"
        md += "| Length | Whisper | Gemma | Whisper ms | Gemma ms | Total ms |\n"
        md += "|---|---|---|---:|---:|---:|\n"
        for row in rows {
            md += "| \(row.lengthLabel) | \(row.whisperLabel) | \(row.gemmaLabel) "
            md += "| \(Int(row.whisperMs)) | \(Int(row.gemmaMs)) | \(Int(row.whisperMs + row.gemmaMs)) |\n"
        }
        md += "\n## Transcripts\n\n"
        for row in rows {
            md += "### \(row.lengthLabel) — \(row.whisperLabel) + \(row.gemmaLabel)\n\n"
            if let err = row.error {
                md += "**Error:** \(err)\n\n"
            }
            md += "**Raw (Whisper):**\n\n> \(row.rawTranscript.replacingOccurrences(of: "\n", with: " "))\n\n"
            md += "**Cleaned (Gemma):**\n\n> \(row.cleanedTranscript.replacingOccurrences(of: "\n", with: " "))\n\n"
        }

        let outPath = URL(fileURLWithPath: audioDirPath)
            .deletingLastPathComponent()
            .appendingPathComponent("results.md")
        try md.write(to: outPath, atomically: true, encoding: .utf8)
        print("✓ Wrote \(outPath.path)")
        #expect(!rows.isEmpty)
    }

    private func benchContext() -> AppContext {
        AppContext(
            appName: nil,
            bundleIdentifier: nil,
            windowTitle: nil,
            selectedText: nil,
            currentActivity: "Benchmark run (no app context).",
            contextPrompt: nil,
            screenshotDataURL: nil,
            screenshotMimeType: nil,
            screenshotError: nil
        )
    }
}
