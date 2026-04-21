<p align="center">
  <img src="Resources/AppIcon-Source.png" width="128" height="128" alt="geMMaFloW icon">
</p>

<h1 align="center">geMMaFloW</h1>

<p align="center">
  100% local, private dictation for macOS — <b>Whisper + Gemma 4</b>, no cloud.
</p>

<p align="center">
  <sub>Apple Silicon · macOS 14+ · MIT licensed</sub>
</p>

---

## What is this?

geMMaFloW is a fork of [FreeFlow](https://github.com/zachlatta/freeflow) by [Zach Latta](https://github.com/zachlatta). FreeFlow is already a great free alternative to Wispr Flow / Superwhisper / Monologue, but it sends your audio to Groq's cloud for transcription and post-processing.

I wanted the same UX **without any network round-trip**. So I replaced the two cloud calls with on-device models:

| Stage | FreeFlow upstream | **geMMaFloW** |
|---|---|---|
| Speech → text | Groq Whisper (cloud) | **[WhisperKit](https://github.com/argmaxinc/WhisperKit)** local |
| Text cleanup + context | Groq gpt-oss / Llama (cloud) | **[Gemma 4 E4B](https://ai.google.dev/gemma) via [MLX Swift](https://github.com/ml-explore/mlx-swift-lm)** local |

Audio never leaves your Mac. LLM inference never leaves your Mac. The app downloads the models on first use (Whisper ~630 MB – 1.5 GB, Gemma 4 E4B ~3.8 GB) and runs entirely offline after that.

## How it works

1. Hold `Fn` (or your custom shortcut) and talk
2. Whisper transcribes locally on Apple Silicon's Neural Engine
3. Gemma 4 cleans up the transcript (removes filler, fixes punctuation, preserves your intent, adapts to the app you're dictating into)
4. Cleaned text is pasted into whatever field you were in

Both models stay resident in RAM after first load — a second dictation is just a few seconds end-to-end.

## Requirements

- **macOS 14 (Sonoma) or newer**
- **Apple Silicon Mac** (M1 / M2 / M3 / M4 / M5). Intel Macs are not supported.
- About 5 GB of disk space for the downloaded models
- 16 GB of RAM recommended (8 GB works but tight when Gemma 4 E4B is loaded)

## Status

This is a personal fork in active development. It builds and runs, but the onboarding and defaults are being rewritten. For now you may need to manually configure the provider in Settings → Advanced to `local://whisperkit` and `local://mlx` to get the fully local pipeline.

See [`docs/analysis/PLAN.md`](docs/analysis/PLAN.md) for the roadmap.

## Credits

- Upstream [FreeFlow](https://github.com/zachlatta/freeflow) by Zach Latta — the UX, the dictation pipeline scaffolding, and all the clever bits around context-aware post-processing
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax for the on-device speech recognition
- [MLX Swift](https://github.com/ml-explore/mlx-swift) by Apple and [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) for native Swift LLM inference
- [Gemma 4](https://ai.google.dev/gemma) by Google DeepMind

## License

MIT — same as the FreeFlow upstream. See [LICENSE](LICENSE) (Copyright © 2026 Zach Latta, preserved as required).
